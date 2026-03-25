import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logger/logger.dart';
import 'package:animate_do/animate_do.dart';
import 'your_profile_screen.dart';
import 'set_code_word_screen.dart';
import 'add_emergency_contacts.dart';
import 'login_screen.dart';
import 'sos_history_screen.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';
import '../services/whatsapp_service.dart';
import '../utils/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _text = '';
  bool _isLocationEnabled = false;
  bool _isActivated = false;
  bool _servicesReady = false; // Master toggle state

  // For Recurring Updates
  Timer? _locationUpdateTimer;

  // Track if SOS was already triggered during this session to avoid multiple sends
  bool _sosTriggered = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger services on app launch (No clicking required)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggleServices(true);
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _speechToText.stop();
    super.dispose();
  }

  // Master switch to turn ON Location and Mic
  Future<void> _toggleServices(bool value) async {
    if (value) {
      _showSnackBar('Configuring Services...', Colors.blue);
      // 1. Enable Location
      await _enableLocationServices();
      // 2. STT Initialization with callbacks
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          logger.d("STT Status: $status");
          if (status == 'notListening' && _isListening && !_isActivated) {
            // Auto-restart if it stops but we still want to be listening
            Future.delayed(const Duration(milliseconds: 500), () => _startListeningLoop());
          }
        },
        onError: (error) {
          logger.e("STT Error: $error");
          if (_isListening) {
             Future.delayed(const Duration(seconds: 1), () => _startListeningLoop());
          }
        },
      );
      
      setState(() {
        _servicesReady = available && _isLocationEnabled;
        if (_servicesReady) {
          _isListening = true;
          _text = '';
          _sosTriggered = false;
        }
      });

      if (_servicesReady) {
        _startListeningLoop();
        _showSnackBar('Microphone & Location READY - PROTECTING', Colors.green);
      } else {
        _showSnackBar('Please grant all permissions', AppTheme.emergencyColor);
      }
    } else {
      setState(() {
        _servicesReady = false;
        _isActivated = false;
        _isListening = false;
      });
      _speechToText.stop();
      _locationUpdateTimer?.cancel();
      _showSnackBar('Services turned OFF', Colors.orange);
    }
  }

  void _startListeningLoop() async {
    if (!_isListening || _isActivated || !_servicesReady) return;
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _text = result.recognizedWords;
          logger.d("Heard: \$_text");
        });
        _checkCodewordInResult(_text);
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5),
      cancelOnError: false,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  void toggleListening() async {
    if (!_servicesReady) {
      _showSnackBar('Turn on Services first!', AppTheme.emergencyColor);
      return;
    }

    if (_isListening || _isActivated) {
      await _speechToText.stop();
      _locationUpdateTimer?.cancel();
      setState(() {
        _isListening = false;
        _isActivated = false;
        _sosTriggered = false;
        logger.d("Stopped Listening/Activation");
      });
    } else {
      setState(() {
        _isListening = true;
        _isActivated = false;
        _text = '';
        _sosTriggered = false;
      });
      _startListeningLoop();
    }
  }

  // Backup Manual SOS for the teacher demo
  Future<void> _manualForceSOS() async {
    _triggerAlarmProcedure('Manual Override');
  }

  Future<void> _logSOSHistory({required String type}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sos_history')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'type': type,
        });
        logger.d("SOS History logged successfully for type: $type");
      } catch (e) {
        logger.e("Failed to log SOS history: $e");
      }
    } else {
      logger.w("Cannot log SOS history: User is null");
    }
  }

  void _startRecurringUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (_isActivated) {
        logger.d("Sending recurring 3-minute location update...");
        _sendSOSMessages();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkCodewordInResult(String spokenText) async {
    if (_sosTriggered || _isActivated) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final normalizedSpoken = spokenText.trim().toLowerCase();
    
    // Check for codeword - local check first for speed
    if (normalizedSpoken.contains('help') || normalizedSpoken.contains('danger')) {
       _triggerAlarmProcedure('Voice (Instant)');
       return;
    }

    // Still check Firestore for custom codewords
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final savedCodeWord = (doc.data()?['codeword'] ?? '').toString().trim().toLowerCase();
        if (savedCodeWord.isNotEmpty && normalizedSpoken.contains(savedCodeWord)) {
          _triggerAlarmProcedure('Voice (Custom)');
        }
      }
    } catch (e) {
      logger.e("Firestore check error: $e");
    }
  }

  void _triggerAlarmProcedure(String source) {
    if (_sosTriggered) return;
    
    _sosTriggered = true;
    logger.i("🔥 SOS TRIGGERED via $source");

    setState(() {
      _isActivated = true;
      _isListening = false;
      _speechToText.stop();
    });

    _showSnackBar('🚨 SOS ACTIVATED! 🚨', AppTheme.emergencyColor);
    
    // Instant actions
    _logSOSHistory(type: source);
    _sendSOSMessages();
    _startRecurringUpdates();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _enableLocationServices() async {
    final location = Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      setState(() {
        _isLocationEnabled = true;
      });
    } catch (e) {
      logger.e("Location error: $e");
      _isLocationEnabled = false;
    }
  }

  Future<void> _sendSOSMessages() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data == null || !data.containsKey('contactList')) return;

      final dynamic rawContacts = data['contactList'];
      logger.d("Raw contacts from Firestore: $rawContacts");
      List<String> contactsList = [];
      
      if (rawContacts is Map) {
        contactsList = rawContacts.values.map((e) => e.toString().trim()).toList();
      } else if (rawContacts is List) {
        contactsList = rawContacts.map((e) => e.toString().trim()).toList();
      }

      logger.i("Sending SOS to ${contactsList.length} contacts: $contactsList");

      if (contactsList.isEmpty) {
        logger.w("No emergency contacts found! Message aborted.");
        return;
      }

      String locationLink = 'https://www.google.com/maps/search/?api=1&query=20.5937,78.9629';
      try {
        final Location location = Location();
        final LocationData currentLocation = await location.getLocation();
        locationLink = 'https://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}';
      } catch (e) {
        logger.w("Could not fetch location: $e");
      }

      final String message = '🚨 SOS ALERT! My current location: $locationLink';

      for (final contact in contactsList) {
        try {
          logger.d("Calling WhatsApp service for $contact...");
          await WhatsAppService.sendWhatsAppAlert(contact, message);
          
          if (!kIsWeb && Theme.of(context).platform == TargetPlatform.android) {
            final Telephony telephony = Telephony.instance;
            await telephony.sendSms(to: contact, message: message);
          }
        } catch (e) {
          logger.e("Failed to send to $contact: $e");
        }
      }
    } catch (e) {
      logger.e("Global Send Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        FadeInDown(
                          duration: const Duration(milliseconds: 800),
                          child: _buildStatusCards(),
                        ),
                        const SizedBox(height: 60),
                        ZoomIn(
                          duration: const Duration(milliseconds: 1000),
                          child: _buildSOSButton(),
                        ),
                        const SizedBox(height: 60),
                        FadeInUp(
                          duration: const Duration(milliseconds: 800),
                          child: _buildFeedbackSection(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 30, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          // MASTER TOGGLE IN APP BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _servicesReady ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _servicesReady ? Colors.green.withOpacity(0.3) : Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  _servicesReady ? Icons.check_circle_rounded : Icons.sensors_off_rounded,
                  color: _servicesReady ? Colors.green : Colors.white24,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _servicesReady ? 'READY' : 'OFF',
                  style: TextStyle(
                    color: _servicesReady ? Colors.green : Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _servicesReady,
                    onChanged: _toggleServices,
                    activeColor: Colors.green,
                    inactiveTrackColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statusIndicator(
          icon: Icons.location_on_rounded,
          label: 'GPS',
          isActive: _isLocationEnabled,
          activeColor: Colors.blue,
        ),
        _statusIndicator(
          icon: Icons.mic_rounded,
          label: 'VOICE',
          isActive: _isListening,
          activeColor: Colors.green,
        ),
        _statusIndicator(
          icon: Icons.notifications_active_rounded,
          label: 'ALARM',
          isActive: _isActivated,
          activeColor: AppTheme.emergencyColor,
        ),
      ],
    );
  }

  Widget _statusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.1) : Colors.white12,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActive ? activeColor.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? activeColor : Colors.white24,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.white : Colors.white24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: toggleListening,
      onLongPress: _manualForceSOS,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isListening || _isActivated)
            _buildPulseEffect(_isActivated ? AppTheme.emergencyColor : AppTheme.primaryColor),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isActivated ? AppTheme.emergencyColor : (_isListening ? AppTheme.primaryColor : AppTheme.emergencyColor),
              boxShadow: [
                BoxShadow(
                  color: (_isActivated || !_isListening ? AppTheme.emergencyColor : AppTheme.primaryColor).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
              gradient: RadialGradient(
                colors: [
                  (_isActivated || !_isListening ? AppTheme.emergencyColor : AppTheme.primaryColor),
                  (_isActivated || !_isListening ? AppTheme.emergencyColor : AppTheme.primaryColor).withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isActivated ? Icons.warning_amber_rounded : (_isListening ? Icons.hearing_rounded : Icons.power_settings_new_rounded),
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  _isActivated ? 'ACTIVATED!' : (_isListening ? 'LISTENING...' : 'ACTIVATE\nSOS'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                if (!_isListening && !_isActivated)
                   const Padding(
                     padding: EdgeInsets.only(top: 8.0),
                     child: Text("(Hold for Manual SOS)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                   ),
                if (_isActivated)
                   const Padding(
                     padding: EdgeInsets.only(top: 8.0),
                     child: Text("(Tap to Reset)", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPulseEffect(Color color) {
    return Pulse(
      infinite: true,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        String activeCodeword = "...";
        if (snapshot.hasData && snapshot.data!.exists) {
          activeCodeword = snapshot.data!['codeword'] ?? 'Not Set';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS: ${_isActivated ? "SOS ACTIVE" : (_isListening ? "LISTENING" : "IDLE")}',
                    style: TextStyle(
                      color: _isActivated ? AppTheme.emergencyColor : (_isListening ? Colors.green : AppTheme.subtleTextColor),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'TRIGGER: ${activeCodeword.toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              Text(
                _isActivated ? "Real-time updates sending every 3 mins..." : (_text.isEmpty ? "Waiting for speech..." : _text),
                style: TextStyle(
                  color: _text.isEmpty && !_isActivated ? Colors.white24 : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontStyle: _text.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        );
      }
    );
  }


  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: Column(
        children: [
          _buildDrawerHeader(),
          const SizedBox(height: 20),
          _drawerItem(
            icon: Icons.person_rounded,
            title: 'My Profile',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const YourProfileScreen())),
          ),
          _drawerItem(
            icon: Icons.vpn_key_rounded,
            title: 'Set Code Word',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetCodeWordScreen())),
          ),
          _drawerItem(
            icon: Icons.contacts_rounded,
            title: 'Emergency Contacts',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEmergencyContactsScreen())),
          ),
          _drawerItem(
            icon: Icons.history_rounded,
            title: 'SOS History',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SOSHistoryScreen())),
          ),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          _drawerItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            textColor: AppTheme.emergencyColor,
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'v1.0.0 - PRO EDITION',
              style: TextStyle(color: AppTheme.subtleTextColor, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
      ),
      currentAccountPicture: const CircleAvatar(
        backgroundColor: AppTheme.primaryColor,
        child: Icon(Icons.person, color: Colors.white, size: 40),
      ),
      accountName: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
             return Text(snapshot.data!['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold));
          }
          return const Text('Loading...');
        },
      ),
      accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.white70),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
