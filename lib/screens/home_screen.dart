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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Redundant import removed for web safety
import '../services/whatsapp_service.dart';
import '../utils/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  double _maxSoundLevel = 0.0; // Captures peak volume for emotion

  // For Recurring Updates
  Timer? _locationUpdateTimer;

  // Track if SOS was already triggered during this session to avoid multiple sends
  bool _sosTriggered = false;
  String? _lastDetectedEmotion = 'Urgent';
  String _detectedEmotionDisplay = '';
  String? _currentReportId; // Track the current active incident ID

  @override
  void initState() {
    super.initState();
    // Services now start only on user interaction for better Web compatibility
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
            Future.delayed(const Duration(milliseconds: 500), () => _startListeningLoop());
          }
        },
        onError: (error) {
          logger.e("STT Error: $error");
          if (_isListening) {
             Future.delayed(const Duration(seconds: 1), () => _startListeningLoop());
          }
        },
        /* onSoundLevelChange: (level) {
           if (level > _maxSoundLevel) {
             setState(() => _maxSoundLevel = level);
           }
        } */
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
        _currentReportId = null; // Reset current session
        logger.d("Stopped Listening/Activation");
      });
    } else {
      setState(() {
        _isListening = true;
        _isActivated = false;
        _text = '';
        _sosTriggered = false;
        _maxSoundLevel = 0.0;
      });
      _startListeningLoop();
    }
  }

  // Backup Manual SOS for the teacher demo
  Future<void> _manualForceSOS() async {
    await _triggerAlarmProcedure('Manual Override');
  }

  Future<void> _testBackendConnection() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.statusUrl)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _showSnackBar('✅ Backend Connected Successfully!', Colors.green);
        logger.i("Backend test successful: ${response.body}");
      } else {
        _showSnackBar('❌ Backend Error: ${response.statusCode}', AppTheme.emergencyColor);
      }
    } catch (e) {
      _showSnackBar('❌ Cannot reach Backend at ${ApiConfig.baseUrl}', AppTheme.emergencyColor);
      logger.e("Backend connection failed: $e");
    }
  }

  Future<void> _logSOSHistory({required String type}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyString = prefs.getString('sos_history_local');
      List<dynamic> history = historyString != null ? jsonDecode(historyString) : [];
      
      final newEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
      };
      
      history.insert(0, newEntry); // Most recent first
      
      // Keep only last 50 entries to save memory
      if (history.length > 50) history = history.sublist(0, 50);
      
      await prefs.setString('sos_history_local', jsonEncode(history));
      logger.i("✅ SOS History saved to LOCAL STORAGE");
    } catch (e) {
      logger.e("❌ Failed to log SOS history locally: $e");
    }
  }

  void _startRecurringUpdates() {
    _locationUpdateTimer?.cancel();
    logger.i("⏳ Starting 3-minute recurring update timer...");
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (_isActivated) {
        logger.i("🕒 3-Minute Cycle Reached: Sending location update...");
        _sendSOSMessages(isRecurring: true, emotion: _lastDetectedEmotion); // Pass the last detected emotion
      } else {
        logger.i("⏹️ SOS Deactivated: Stopping recurring updates.");
        timer.cancel();
      }
    });
  }

  Future<void> _checkCodewordInResult(String spokenText) async {
    if (_sosTriggered || _isActivated) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("⚠️ VOICE_TRIGGER: No user logged in. Ignoring speech.");
      return;
    }
    print("🎤 VOICE_TRIGGER: Heard text: '$spokenText'");

    final normalizedSpoken = spokenText.trim().toLowerCase();
    
    // 1. Check LOCAL storage first (fast & works offline)
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCodeword = (prefs.getString('cached_codeword') ?? '').trim().toLowerCase();
      if (localCodeword.isNotEmpty && normalizedSpoken.contains(localCodeword)) {
        await _triggerAlarmProcedure('Voice (Local Cache)', codeword: localCodeword);
        return;
      }
    } catch (e) {
      logger.e("Local codeword check error: $e");
    }

    // 2. Check Firestore (Sync and update cache)
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final savedCodeWord = (doc.data()?['codeword'] ?? '').toString().trim().toLowerCase();
        
        // Update local cache for next time
        if (savedCodeWord.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_codeword', savedCodeWord);
          
          if (normalizedSpoken.contains(savedCodeWord)) {
            await _triggerAlarmProcedure('Voice (Custom)', codeword: savedCodeWord);
          }
        }
      }
    } catch (e) {
      logger.e("Firestore check error: $e");
    }
  }

  Future<void> _triggerAlarmProcedure(String source, {String? codeword}) async {
    if (_sosTriggered) return;
    
    _sosTriggered = true;
    print("🔥 SOS_PHASE: Triggered via $source");
    logger.i("🔥 SOS TRIGGERED via $source");

    setState(() {
      _isActivated = true;
      _isListening = false;
      _speechToText.stop();
      _detectedEmotionDisplay = 'Analyzing...';
      _currentReportId = FirebaseFirestore.instance.collection('sos_reports').doc().id; 
    });

    // --- Phase 1: Rapid Data Fetch & Location Lock ---
    String userName = 'A Citizen';
    String userPhone = '';
    String userEmail = '';
    String userAddress = '';
    String userBlood = '';
    String userPhoto = '';
    double? currentLat;
    double? currentLng;
    String locationLink = 'Unknown';

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        userName = d['name'] ?? userName;
        userPhone = d['phone'] ?? '';
        userEmail = d['email'] ?? '';
        userAddress = d['address'] ?? '';
        userBlood = d['bloodType'] ?? '';
        userPhoto = d['photoUrl'] ?? '';
      }
    }

    try {
      final locData = await Location().getLocation().timeout(const Duration(seconds: 5));
      currentLat = locData.latitude;
      currentLng = locData.longitude;
      locationLink = 'https://www.google.com/maps/search/?api=1&query=$currentLat,$currentLng';
    } catch (_) {}

    // --- INSTANT DISPATCH: Phase 2 (Emergency Alerts) ---
    _sendSOSMessages(isRecurring: false, emotion: "Urgent (Context Analyzing...)");
    _showSnackBar('🚨 SOS ACTIVATED - ALERTS DISPATCHED!', AppTheme.emergencyColor);

    // --- PHASE 3: Rapid Situation Analysis & UI Update ---
    String finalEmotionLabel = "Urgent SOS";
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCodeword = prefs.getString('cached_codeword') ?? 'help';
      
      final response = await http.post(
        Uri.parse(ApiConfig.reportSosUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': _currentReportId,
          'userId': user?.uid,
          'userName': userName,
          'userPhone': userPhone,
          'userEmail': userEmail,
          'userAddress': userAddress,
          'userBlood': userBlood,
          'userPhoto': userPhoto,
          'message': _text, 
          'codeword': localCodeword,
          'lat': currentLat ?? 0.0,
          'lng': currentLng ?? 0.0,
          'locationLink': locationLink,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        finalEmotionLabel = result['emotion'] ?? 'Panic / Terror';
        
        setState(() {
          _detectedEmotionDisplay = finalEmotionLabel;
          _lastDetectedEmotion = finalEmotionLabel;
        });
      }
    } catch (e) {
      logger.e("Instant analysis skip: $e");
      setState(() {
         _detectedEmotionDisplay = 'SOS Active';
      });
    }

    // --- HUMAN-GRADE NEURAL VOICE SELECTION ---
    try {
      if (kIsWeb) {
        final voices = await _flutterTts.getVoices;
        if (voices != null && voices is List) {
          dynamic bestVoice = voices.firstWhere(
            (v) => v.toString().contains('en-us-x-sfg'),
            orElse: () => voices.firstWhere(
              (v) => v.toString().contains('Google') && v.toString().contains('en-US'),
              orElse: () => voices.firstWhere(
                (v) => v.toString().toLowerCase().contains('female') && v.toString().contains('en-US'),
                orElse: () => null
              )
            ),
          );

          if (bestVoice != null) {
            Map<String, String> voiceMap = Map<String, String>.from(bestVoice);
            await _flutterTts.setVoice(voiceMap);
          } else {
             await _flutterTts.setLanguage("en-US");
          }
        }
      }
    } catch (e) {
      logger.w("Voice selection failed: $e");
    }

    _logSOSHistory(type: "$source ($finalEmotionLabel)");
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
      logger.i("🎯 Location Services Enabled");
    } catch (e) {
      logger.e("Location error: $e");
      _isLocationEnabled = false;
    }
  }

  Future<void> _sendSOSMessages({bool isRecurring = false, String? emotion}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       print("❌ ALERT_PHASE: Cannot send messages, user is NULL");
       return;
    }
    print("🚀 ALERT_PHASE: Processing SOS Message sending...");

    List<String> contactsList = [];
    Map<String, dynamic>? contactsMap;
    String userName = 'Your contact';
    String userPhone = 'N/A';
    String userEmail = 'N/A';
    String userAddress = 'N/A';
    String userBlood = 'N/A';
    String userPhoto = '';

    print("🚀 ALERT_PHASE: Fetching data from Firestore for UID: ${user.uid}");
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 5));
      if (doc.exists) {
        final data = doc.data()!;
        final dynamic rawContacts = data['contactList'];
        print("✅ ALERT_PHASE: Raw Contacts data: $rawContacts");
        if (rawContacts is Map) {
          contactsMap = Map<String, dynamic>.from(rawContacts);
          contactsList = contactsMap.keys.toList();
        } else if (rawContacts is List) {
          contactsList = rawContacts.map((e) => e.toString().trim()).toList();
        }
        userName = data['name'] ?? 'Your contact';
        userPhone = data['phone'] ?? 'N/A';
        userEmail = data['email'] ?? 'N/A';
        userAddress = data['address'] ?? 'N/A';
        userBlood = data['bloodType'] ?? 'N/A';
        userPhoto = data['photoUrl'] ?? '';
        print("✅ ALERT_PHASE: UserName: $userName, ContactsCount: ${contactsList.length}");
        
        // Cache for fail-safe
        final prefs = await SharedPreferences.getInstance();
        if (contactsList.isNotEmpty) {
          await prefs.setStringList('cached_contacts', contactsList);
          await prefs.setString('cached_user_name', userName);
        }
      } else {
        print("⚠️ ALERT_PHASE: User document does NOT exist in Firestore");
      }
    } catch (e) {
      print("❌ ALERT_PHASE: Firestore Fetch Failed: $e");
      final prefs = await SharedPreferences.getInstance();
      contactsList = prefs.getStringList('cached_contacts') ?? [];
      userName = prefs.getString('cached_user_name') ?? 'Your contact';
    }

    if (contactsList.isEmpty) {
      print("⚠️ ALERT_PHASE: ABORTED - contactsList is EMPTY");
      logger.w("No contacts found (Firestore & Cache empty)!");
      if (!isRecurring) _showSnackBar('No emergency contacts set!', AppTheme.emergencyColor);
      return;
    }
    print("✅ ALERT_PHASE: Found ${contactsList.length} contacts. Proceeding to send.");

    String locationLink = 'Location Unavailable (Check Connectivity)';
    double? currentLat;
    double? currentLng;

    try {
      final Location location = Location();
      logger.d("📍 Fetching precise coordinates...");
      final LocationData currentLocation = await location.getLocation().timeout(
        isRecurring ? const Duration(seconds: 15) : const Duration(seconds: 10)
      );
      
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        currentLat = currentLocation.latitude;
        currentLng = currentLocation.longitude;
        locationLink = 'https://www.google.com/maps/search/?api=1&query=${currentLocation.latitude},${currentLocation.longitude}';
        logger.i("✅ Precise Location Lat: ${currentLocation.latitude}, Lng: ${currentLocation.longitude}");
      }
    } catch (e) {
      logger.w("⚠️ Precise location fetch timed out or failed: $e. Falling back to last known if possible.");
      try {
        final lastLoc = await Location().getLocation().timeout(const Duration(seconds: 3)); 
        if (lastLoc.latitude != null && lastLoc.longitude != null) {
           currentLat = lastLoc.latitude;
           currentLng = lastLoc.longitude;
           locationLink = 'https://www.google.com/maps/search/?api=1&query=${lastLoc.latitude},${lastLoc.longitude}';
        }
      } catch (_) {
         logger.e("💀 Could not determine location at all.");
      }
    }

    // --- PERSISTENT SECURITY ARCHIVE (Every SOS is a unique record) ---
    if (_currentReportId != null) {
      FirebaseFirestore.instance.collection('sos_reports').doc(_currentReportId).set({
        'reportId': _currentReportId,
        'userId': user.uid,
        'userName': userName,
        'userPhone': userPhone,
        'userEmail': userEmail,
        'userAddress': userAddress,
        'userBlood': userBlood,
        'userPhoto': userPhoto,
        'emotion': emotion,
        'location': locationLink,
        'lat': currentLat ?? 0.0,
        'lng': currentLng ?? 0.0,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      }, SetOptions(merge: true));
    }

    // --- GLOBAL POLICE DASHBOARD SYNC (Legacy Compatibility) ---
    FirebaseFirestore.instance.collection('active_sos').doc(user.uid).set({
      'userId': user.uid,
      'userName': userName,
      'emotion': emotion,
      'location': locationLink,
      'lat': currentLat ?? 0.0,
      'lng': currentLng ?? 0.0,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    }, SetOptions(merge: true));

    // --- 💎 NEW: COMMAND CENTER SYNC (MONGODB + PRIVATE API) ---
    // This bypasses Firebase Security Rules and ensures persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCodeword = prefs.getString('cached_codeword') ?? 'help';
      
      http.post(
        Uri.parse(ApiConfig.reportSosUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': _currentReportId,
          'userId': user.uid,
          'userName': userName,
          'userPhone': userPhone,
          'userEmail': userEmail,
          'userAddress': userAddress,
          'userBlood': userBlood,
          'userPhoto': userPhoto,
          'message': _text, // SEND RAW SPEECH FOR IMMEDIATE ANALYSIS
          'codeword': localCodeword,
          'lat': currentLat ?? 0.0,
          'lng': currentLng ?? 0.0,
          'locationLink': locationLink,
        }),
      ).timeout(const Duration(seconds: 5)).catchError((e) {
          debugPrint("API POST Failed: $e");
          return http.Response('', 500);
      });
    } catch (e) {
      debugPrint("Backend Sync Error: $e");
    }

    logger.i("🎯 Attempting to alert ${contactsList.length} contacts: $contactsList");
    
    // Create the message first so we don't wait for location to start looping if it fails
    String specializedStatus = "";
    if (emotion != null) {
      if (emotion.contains("Terror")) specializedStatus = "\n⚠️ SITUATION CRITICAL: Extreme panic detected.";
      else if (emotion.contains("Anger")) specializedStatus = "\n⚠️ SITUATION URGENT: Conflict detected.";
      else if (emotion.contains("Pain")) specializedStatus = "\n⚠️ SITUATION CRITICAL: Physical injury detected.";
      else if (emotion.contains("Sadness") || emotion.contains("Hiding")) specializedStatus = "\n⚠️ SITUATION SENSITIVE: User is hiding.";
      else specializedStatus = "\n⚠️ SITUATION URGENT: High stress detected.";
    }

    final String timeStamp = DateTime.now().toLocal().toString().substring(11, 16);
    final String safeEmotion = (emotion == null || emotion.isEmpty) ? "Urgent Distress" : emotion;
    
    final String baseMessage = isRecurring 
      ? '📍 [OFFICIAL UPDATE - $timeStamp]: $userName is still in a $safeEmotion state. Please remain on standby. '
      : '🚨 HIGH-PRIORITY SAFETY NOTIFICATION [$timeStamp]: $userName has activated an SOS emergency alert. \n\n🧠 SITUATION: $safeEmotion.';

    // Start sending to each contact
    for (final contactName in contactsList) {
      try {
        final contactData = (contactsMap != null) ? contactsMap[contactName] : null;
        String? phone;
        String? email;
        
        if (contactData is Map) {
          phone = contactData['phone']?.toString();
          email = contactData['email']?.toString();
        } else {
          phone = contactData?.toString();
        }

        print("🚀 ALERT_PHASE: Processing Contact [$contactName] -> Phone: $phone, Email: $email | Full Data: $contactData");

        final String finalMessage = "$baseMessage Please check live location here: $locationLink";

        // --- DISABLE EMAIL DISPATCH (Per User Request) ---
        /*
        if (email != null && email.isNotEmpty) {
           print("📧 ALERT_PHASE: Dispatching Email to $email");
           // ignore: unawaited_futures
           WhatsAppService.sendEmailAlert(email, finalMessage);
        }
        */

        if (phone != null && phone.isNotEmpty) {
          if (!isRecurring) {
            final String voiceMessage = "Emergency alert! $userName needs help. Situational context: $emotion. Check your SMS for live location.";
            print("📞 ALERT_PHASE: Dispatching Voice Call to $phone");
            // ignore: unawaited_futures
            WhatsAppService.makeVoiceCall(phone, voiceMessage);
          }

          // --- ALWAYS SEND SMS (Initial and Recurring Updates) ---
          print("📱 ALERT_PHASE: Dispatching SMS Alert to $phone (isRecurring: $isRecurring)");
          // ignore: unawaited_futures
          WhatsAppService.sendSMSAlert(phone, finalMessage);
        }
      } catch (e) {
        print("❌ ALERT_PHASE: Error in contact loop for $contactName: $e");
      }
    }
    logger.i("🏁 Alert cycle complete.");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // 🛡️ THE SECURITY GRID BACKGROUND
          Container(
            decoration: AppTheme.gradientBackground,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: GridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          FadeInDown(
                            duration: const Duration(milliseconds: 800),
                            child: _buildStatusCards(),
                          ),
                          const SizedBox(height: 50),
                          ZoomIn(
                            duration: const Duration(milliseconds: 1000),
                            child: _buildSOSButton(),
                          ),
                          const SizedBox(height: 50),
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
           GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.grid_view_rounded, size: 24, color: Colors.white),
            ),
          ),
          
          Text(
            'SOS GUARDIAN',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),

          // MASTER TOGGLE IN APP BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _servicesReady ? Colors.green.withOpacity(0.05) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _servicesReady ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _servicesReady ? Colors.green : Colors.white24,
                    shape: BoxShape.circle,
                    boxShadow: _servicesReady ? [
                      BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                    ] : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _servicesReady ? 'EYE ON' : 'OFF',
                  style: TextStyle(
                    color: _servicesReady ? Colors.green : Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.65,
                  child: Switch(
                    value: _servicesReady,
                    onChanged: _toggleServices,
                    activeColor: Colors.green,
                    inactiveTrackColor: Colors.white12,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statusIndicator(
            icon: Icons.gps_fixed_rounded,
            label: 'GPS LOCK',
            isActive: _isLocationEnabled,
            activeColor: Colors.blueAccent,
          ),
          Container(width: 1, height: 30, color: Colors.white10),
          _statusIndicator(
            icon: Icons.mic_none_rounded,
            label: 'VOICE AI',
            isActive: _isListening,
            activeColor: Colors.greenAccent,
          ),
          Container(width: 1, height: 30, color: Colors.white10),
          _statusIndicator(
            icon: Icons.shield_outlined,
            label: 'SECURITY',
            isActive: _isActivated,
            activeColor: AppTheme.emergencyColor,
          ),
        ],
      ),
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
          
          // Outer Glow
          Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
          ),

          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isActivated ? AppTheme.emergencyColor : (_isListening ? AppTheme.primaryColor : AppTheme.emergencyColor),
              boxShadow: [
                BoxShadow(
                  color: (_isActivated || !_isListening ? AppTheme.emergencyColor : AppTheme.primaryColor).withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (_isActivated || !_isListening ? AppTheme.emergencyColor : AppTheme.primaryColor),
                  (_isActivated || !_isListening ? const Color(0xFF640000) : const Color(0xFF003D4D)),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(
                  _isActivated ? Icons.shield_rounded : (_isListening ? Icons.hearing_rounded : Icons.power_settings_new_rounded),
                  size: 50,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  _isActivated ? 'ACTIVE' : (_isListening ? 'LISTENING' : 'ACTIVATE'),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, prefsSnapshot) {
        final String cachedCodeword = prefsSnapshot.data?.getString('cached_codeword') ?? '...';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            String activeCodeword = cachedCodeword;
            if (snapshot.hasData && snapshot.data!.exists) {
              activeCodeword = snapshot.data!['codeword'] ?? activeCodeword;
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
                  if (_isActivated && _detectedEmotionDisplay.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology_outlined, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'EMOTION: ${_detectedEmotionDisplay.toUpperCase()}',
                            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
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
          },
        );
      },
    );
  }


  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF040608),
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Column(
          children: [
            _buildDrawerHeader(),
            const SizedBox(height: 20),
            _drawerItem(
              icon: Icons.person_rounded,
              title: 'MY PROFILE',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const YourProfileScreen())),
            ),
            _drawerItem(
              icon: Icons.vpn_key_rounded,
              title: 'CODE WORDS',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetCodeWordScreen())),
            ),
            _drawerItem(
              icon: Icons.contacts_rounded,
              title: 'EMERGENCY CONTACTS',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEmergencyContactsScreen())),
            ),
            _drawerItem(
              icon: Icons.history_rounded,
              title: 'INCIDENT LOGS',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SOSHistoryScreen())),
            ),
            _drawerItem(
              icon: Icons.electrical_services_rounded,
              title: 'SYSTEM TEST',
              onTap: () {
                 Navigator.pop(context);
                 _testBackendConnection();
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(color: Colors.white10),
            ),
            _drawerItem(
              icon: Icons.logout_rounded,
              title: 'OFFLINE / LOGOUT',
              textColor: AppTheme.emergencyColor,
              onTap: () {
                FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SOS GUARDIAN v1.0 PRO',
                    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5))),
            child: const CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white12,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              String name = "SECURE USER";
              if (snapshot.hasData && snapshot.data!.exists) {
                name = (snapshot.data!['name'] ?? name).toString().toUpperCase();
              }
              return Text(
                name,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
              );
            },
          ),
          Text(
            user?.email?.toUpperCase() ?? 'OFFLINE',
            style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.white54, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          color: textColor ?? Colors.white, 
          fontSize: 13, 
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      onTap: onTap,
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
