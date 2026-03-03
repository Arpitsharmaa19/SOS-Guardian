import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetCodeWordScreen extends StatefulWidget {
  const SetCodeWordScreen({super.key});

  @override
  State<SetCodeWordScreen> createState() => _SetCodeWordScreenState();
}

class _SetCodeWordScreenState extends State<SetCodeWordScreen> {
  final TextEditingController _codeWordController = TextEditingController();
  String? _presetCodeWord;

  @override
  void initState() {
    super.initState();
    _fetchPresetCodeWord();
  }

  Future<void> _fetchPresetCodeWord() async {
    try {
      // Get the currently logged-in user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        String userId = user.uid;

        // Fetch the user's document from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        // Check if the document exists and contains a codeword field
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _presetCodeWord = data['codeword'] ?? '';
            _codeWordController.text = _presetCodeWord!; // Populate the field
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user is logged in')),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch preset code word: $e')),
      );
    }
  }

  Future<void> _saveCodeWord() async {
    final String codeWord = _codeWordController.text.trim();

    if (codeWord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a code word')),
      );
      return;
    }

    try {
      // Get the currently logged-in user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        String userId = user.uid;

        // Save the code word to Firestore under the user's document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'codeword': codeWord,
        });

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code word saved successfully')),
        );

        // Clear the text field after saving
        _codeWordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user is logged in')),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save code word: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Code Word')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codeWordController,
              decoration: const InputDecoration(labelText: 'Code Word'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveCodeWord,
              child: const Text('Save'),
            ),
            if (_presetCodeWord != null && _presetCodeWord!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Preset Code Word: $_presetCodeWord',
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
