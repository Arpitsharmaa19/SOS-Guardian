import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logger/logger.dart';
import 'your_profile_screen.dart';
import 'set_code_word_screen.dart';
import 'add_emergency_contacts.dart';
import 'login_screen.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';

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

  void toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
        logger.d("Stopped Listening");
        _compareCodeWords();
      });
    } else {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speechToText.listen(onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
          });
        });
      } else {
        logger.w("Speech recognition is not available");
      }
    }
  }

  void refreshPage() {
    setState(() {
      _text = '';
      if (_isListening) {
        _speechToText.stop();
        _isListening = false;
      }
      logger.d("Page refreshed: Ready to listen again");
    });
  }

  Future<void> _compareCodeWords() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final savedCodeWord = doc.data()?['codeword'] ?? '';
        final normalizedSavedCodeWord = savedCodeWord.trim().toLowerCase();
        final normalizedSpokenWord = _text.trim().toLowerCase();

        logger.d('Saved Code Word: "$normalizedSavedCodeWord"');
        logger.d('Spoken Word: "$normalizedSpokenWord"');

        if (normalizedSpokenWord == normalizedSavedCodeWord) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code words matched! SOS activated')),
          );
          logger.d("Code words matched");
          await _sendSOSMessages();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code words do not match')),
          );
          logger.w("Code words did not match");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code word not set')),
        );
      }
    } catch (e) {
      logger.e("Error fetching code word: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _enableLocationServices() async {
    final location = Location();

    // Check if location services are enabled
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location services are required to proceed.')),
        );
        return;
      }
    }

    // Check location permissions
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }

    // If location services and permissions are enabled
    if (!mounted) return;
    setState(() {
      _isLocationEnabled = true; // Update the state
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location is now enabled.')),
    );
  }

  Future<void> _sendSOSMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    final Telephony telephony = Telephony.instance;

    if (user == null) return;

    try {
      bool? isTelephonyAvailable = await telephony.isSmsCapable;
      if (isTelephonyAvailable == null || !isTelephonyAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS is not supported on this device.')),
        );
        return;
      }

      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permissions are required.')),
        );
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data == null || !data.containsKey('contactList')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No emergency contacts found')),
        );
        return;
      }

      final contactList = Map<String, String>.from(data['contactList']);
      final contacts = contactList.values.toList();

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid contacts found')),
        );
        return;
      }

      final Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is denied')),
          );
          return;
        }
      }

      final LocationData currentLocation = await location.getLocation();
      final String locationLink =
          'https://www.google.com/maps/search/?api=1&query=${currentLocation.latitude},${currentLocation.longitude}';

      final String message =
          'SOS Alert! I need help immediately. My current location: $locationLink';

      for (final contact in contacts) {
        await telephony.sendSms(
          to: contact,
          message: message,
          isMultipart: true,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS messages sent successfully!')),
      );
    } catch (e) {
      logger.e("Error sending SOS messages: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void showLocationPopup() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Required"),
        content: const Text("Please turn on your location to activate SOS."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await _enableLocationServices(); // Enable system location
            },
            child: const Text("Turn On Location"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('SOS Voice Activation'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 168, 94, 228)),
              child: Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const YourProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key),
              title: const Text('Set Code Word'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SetCodeWordScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Add Emergency Contacts'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddEmergencyContactsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location Tracking'),
              trailing: Switch(
                value: _isLocationEnabled,
                onChanged: (value) {
                  setState(() {
                    _isLocationEnabled = value;
                  });
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (!_isLocationEnabled) {
                  showLocationPopup();
                } else {
                  toggleListening();
                }
              },
              child: _isListening
                  ? const Text("Stop Listening")
                  : const Text("Activate SOS"),
            ),
            if (_isListening) const CircularProgressIndicator(),
            //const SizedBox(height: 20),
            const SizedBox(height: 20),
            Text(
              _text.isEmpty ? "Say something..." : "You said: $_text",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 100), // Add spacing between text and button
            FloatingActionButton.small(
              onPressed: refreshPage,
              tooltip: 'Refresh',
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
