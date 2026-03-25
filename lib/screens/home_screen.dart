import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logger/logger.dart';
import 'package:animate_do/animate_do.dart';
import 'your_profile_screen.dart';
import 'set_code_word_screen.dart';
import 'add_emergency_contacts.dart';
import 'login_screen.dart';
import 'sos_history_screen.dart';
import 'package:location/location.dart';
import '../services/whatsapp_service.dart';
import '../utils/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

final logger = Logger();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _text = '';
  bool _isLocationEnabled = false;
  bool _isActivated = false;
  bool _servicesReady = false; 

  Timer? _locationUpdateTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 180; // 3 minutes
  bool _sosTriggered = false;
  String? _lastDetectedEmotion = 'Urgent Alert';
  String _detectedEmotionDisplay = '';
  String? _currentReportId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastDetectedEmotion = prefs.getString('user_last_emotion') ?? 'Urgent Alert';
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _countdownTimer?.cancel();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _toggleServices(bool value) async {
    if (value) {
      _showSnackBar('Configuring Security...', Colors.blue);
      await _enableLocationServices();
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'notListening' && _isListening && !_isActivated) {
            Future.delayed(const Duration(milliseconds: 500), () => _startListeningLoop());
          }
        },
        onError: (error) {
          if (_isListening) Future.delayed(const Duration(seconds: 1), () => _startListeningLoop());
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
        _showSnackBar('EYE ON - PROTECTING', Colors.green);
      } else {
        _showSnackBar('Grant Permissions', AppTheme.emergencyColor);
      }
    } else {
      setState(() {
        _servicesReady = false;
        _isActivated = false;
        _isListening = false;
      });
      _speechToText.stop();
      _locationUpdateTimer?.cancel();
      _countdownTimer?.cancel();
      _showSnackBar('Security OFF', Colors.orange);
    }
  }

  void _startListeningLoop() async {
    if (!_isListening || _isActivated || !_servicesReady) return;
    await _speechToText.listen(
      onResult: (result) {
        setState(() => _text = result.recognizedWords);
        _checkCodewordInResult(_text);
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5),
      cancelOnError: false,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _checkCodewordInResult(String spokenText) async {
    if (_sosTriggered || _isActivated) return;
    final prefs = await SharedPreferences.getInstance();
    final localCodeword = (prefs.getString('user_codeword') ?? 'help me').trim().toLowerCase();
    
    if (spokenText.toLowerCase().contains(localCodeword)) {
      await _triggerAlarmProcedure('Voice Detection');
    }
  }

  Future<void> _triggerAlarmProcedure(String source) async {
    if (_sosTriggered) return;
    _sosTriggered = true;

    setState(() {
      _isActivated = true;
      _isListening = false;
      _speechToText.stop();
      _detectedEmotionDisplay = 'Analyzing...';
      _currentReportId = 'R-${DateTime.now().millisecondsSinceEpoch}';
      _secondsRemaining = 180;
    });

    _sendSOSMessages(message: _text);
    _showSnackBar('🚨 SOS ACTIVATED!', AppTheme.emergencyColor);
    _startRecurringUpdates();
    _startCountdown();
  }

  Future<void> _sendSOSMessages({bool isRecurring = false, String? message}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('mongo_user_id');
    final String? userName = prefs.getString('user_name') ?? 'Guardian User';
    final String? userPhone = prefs.getString('user_phone');
    
    if (userId == null) return;

    LocationData? locData;
    String locationLink = 'Unavailable';
    try {
      locData = await Location().getLocation().timeout(const Duration(seconds: 10));
      if (locData.latitude != null) {
        locationLink = 'https://www.google.com/maps/search/?api=1&query=${locData.latitude},${locData.longitude}';
      }
    } catch (e) { logger.e("Loc Error: $e"); }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.reportSosUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': _currentReportId,
          'userId': userId,
          'userName': userName,
          'userPhone': userPhone,
          'message': message,
          'locationLink': locationLink,
          'lat': locData?.latitude ?? 0.0,
          'lng': locData?.longitude ?? 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _lastDetectedEmotion = result['emotion'];
          _detectedEmotionDisplay = result['emotion'];
        });
        await prefs.setString('user_last_emotion', result['emotion']);
      }
    } catch (e) { logger.e("Report Error: $e"); }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isActivated) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _secondsRemaining = 180; // Reset after hit
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startRecurringUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (_isActivated) {
        _sendSOSMessages(isRecurring: true);
        setState(() => _secondsRemaining = 180);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _enableLocationServices() async {
    final loc = Location();
    bool enabled = await loc.serviceEnabled();
    if (!enabled) enabled = await loc.requestService();
    if (enabled) {
      PermissionStatus perm = await loc.hasPermission();
      if (perm == PermissionStatus.denied) perm = await loc.requestPermission();
      setState(() => _isLocationEnabled = perm == PermissionStatus.granted);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Container(decoration: AppTheme.gradientBackground),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        _buildStatusIndicator(),
                        const SizedBox(height: 50),
                        ZoomIn(
                          child: GestureDetector(
                            onLongPress: () => _triggerAlarmProcedure('Manual Press'),
                            child: Container(
                              width: 220, height: 220,
                              decoration: BoxDecoration(
                                color: _isActivated ? Colors.red : AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: _isActivated ? Colors.white : AppTheme.primaryColor, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isActivated ? Colors.red.withOpacity(0.5) : AppTheme.primaryColor.withOpacity(0.3), 
                                    blurRadius: 30, 
                                    spreadRadius: 5
                                  )
                                ]
                              ),
                              child: Center(
                                child: Text(_isActivated ? 'SOS ACTIVE\nDISPATCHING...' : 'HOLD FOR\nEMERGENCY', 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        if (_isActivated) ...[
                          FadeInUp(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.glassDecoration,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('SITUATION AI', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                          const SizedBox(height: 4),
                                          Text(_detectedEmotionDisplay, style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                      const Icon(Icons.analytics_outlined, color: Colors.redAccent, size: 30),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 32),
                                  Text('SPEECH TRANSCRIPT', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _text.isEmpty ? "... listening for emergency context ..." : _text.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                                  ),
                                  const Divider(color: Colors.white10, height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.location_on, color: AppTheme.primaryColor, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'NEXT UPDATE IN ${_secondsRemaining}S',
                                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          FadeInUp(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'VOICE DISPATCH IS ACTIVE. SAY YOUR CODEWORD TO TRIGGER SOS.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          Text('SOS GUARDIAN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Switch(value: _servicesReady, onChanged: _toggleServices, activeColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusDot('GPS', _isLocationEnabled, Colors.blue),
        const SizedBox(width: 20),
        _statusDot('MIC', _isListening, Colors.green),
      ],
    );
  }

  Widget _statusDot(String label, bool active, Color color) {
    return Row(
      children: [
        Container(
          width: 8, height: 8, 
          decoration: BoxDecoration(
            color: active ? color : Colors.white10, 
            shape: BoxShape.circle,
            boxShadow: active ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 5)] : []
          )
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: active ? Colors.white : Colors.white10, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: ListView(
        children: [
          DrawerHeader(child: Center(child: Icon(Icons.shield, color: AppTheme.primaryColor, size: 50))),
          _drawerItem(Icons.history, 'Emergency History', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SOSHistoryScreen()))),
          _drawerItem(Icons.person, 'My Profile', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const YourProfileScreen()))),
          _drawerItem(Icons.contacts, 'Emergency Contacts', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEmergencyContactsScreen()))),
          _drawerItem(Icons.lock, 'Security Codeword', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetCodeWordScreen()))),
          const Divider(color: Colors.white10),
          _drawerItem(Icons.logout, 'Lock Vault', () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          }),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 20),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}
