import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import '../utils/app_theme.dart';

class SetCodeWordScreen extends StatefulWidget {
  const SetCodeWordScreen({super.key});

  @override
  SetCodeWordScreenState createState() => SetCodeWordScreenState();
}

class SetCodeWordScreenState extends State<SetCodeWordScreen> {
  final _codeWordController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCodeWord();
  }

  void _loadCurrentCodeWord() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _codeWordController.text = doc.data()?['codeword'] ?? '';
        });
      }
    }
  }

  void _saveCodeWord() async {
    if (_codeWordController.text.isEmpty) {
      _showSnackBar('Please enter a codeword', AppTheme.emergencyColor);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'codeword': _codeWordController.text.trim(),
        });
        _showSnackBar('Codeword updated successfully', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: $e', AppTheme.emergencyColor);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Secret Codeword')),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.security_rounded, size: 60, color: AppTheme.primaryColor),
                        const SizedBox(height: 20),
                        Text(
                          'Your Emergency Trigger',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'When spoken, this word will instantly trigger all SOS alerts and share your location.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.subtleTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeWordController,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'e.g. HELP',
                          hintStyle: TextStyle(color: Colors.white12),
                          helperText: 'Choose a word that is easy to speak in an emergency',
                          helperStyle: TextStyle(color: AppTheme.subtleTextColor),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _isLoading
                        ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                        : SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _saveCodeWord,
                              child: const Text('SAVE CODEWORD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
