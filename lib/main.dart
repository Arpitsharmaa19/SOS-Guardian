import 'package:VoiceAid/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:telephony/telephony.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOS Voice Activation',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _checkSmsPermissions();
  }

  Future<void> _checkSmsPermissions() async {
    bool? permissionGranted = await telephony.requestSmsPermissions;
    if (permissionGranted != true) {
      debugPrint("SMS Permission not granted!");
    } else {
      debugPrint("SMS Permission granted.");
    }
  }

  Future<void> sendSOS(String contact, String message) async {
    try {
      await telephony.sendSms(
        to: contact,
        message: message,
      );
      debugPrint("SOS SMS sent successfully to $contact!");
    } catch (e) {
      debugPrint("Error sending SOS SMS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS App')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Replace with actual values or use Firestore to fetch the contact and message
            String contact =
                "9657881214"; // Replace with dynamic contact from Firestore
            String message =
                "SOS! I need help!"; // Replace with dynamic message from Firestore
            sendSOS(contact, message);
          },
          child: const Text('Send SOS'),
        ),
      ),
    );
  }
}
