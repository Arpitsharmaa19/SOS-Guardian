import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import '../utils/app_theme.dart';

class AddEmergencyContactsScreen extends StatefulWidget {
  const AddEmergencyContactsScreen({super.key});

  @override
  AddEmergencyContactsScreenState createState() => AddEmergencyContactsScreenState();
}

class AddEmergencyContactsScreenState extends State<AddEmergencyContactsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Map<String, String> _contacts = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('contactList')) {
        setState(() {
          _contacts = Map<String, String>.from(doc.data()!['contactList']);
        });
      }
    }
  }

  void _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar('Provide both name and number', AppTheme.emergencyColor);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _contacts[_nameController.text.trim()] = _phoneController.text.trim();
        await _firestore.collection('users').doc(user.uid).update({
          'contactList': _contacts,
        });
        _nameController.clear();
        _phoneController.clear();
        _showSnackBar('Contact added successfully', Colors.green);
        _loadContacts();
      }
    } catch (e) {
      _showSnackBar('Error: $e', AppTheme.emergencyColor);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteContact(String name) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _contacts.remove(name);
        await _firestore.collection('users').doc(user.uid).update({
          'contactList': _contacts,
        });
        _loadContacts();
        _showSnackBar('Contact removed', AppTheme.emergencyColor);
      }
    } catch (e) {
      _showSnackBar('Error: $e', AppTheme.emergencyColor);
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
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        _buildInputField(_nameController, 'Contact Name', Icons.person_outline),
                        const SizedBox(height: 15),
                        _buildInputField(_phoneController, 'Phone Number', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addContact,
                                child: const Text('ADD CONTACT'),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TRUSTED CIRCLE (${_contacts.length})',
                    style: TextStyle(color: AppTheme.subtleTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: _contacts.isEmpty
                    ? Center(child: Text('No contacts added yet', style: TextStyle(color: AppTheme.subtleTextColor)))
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          String name = _contacts.keys.elementAt(index);
                          String phone = _contacts[name]!;
                          return FadeInUp(
                            delay: Duration(milliseconds: index * 100),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                tileColor: AppTheme.cardColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Icon(Icons.emergency_rounded, color: Colors.white),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(phone, style: TextStyle(color: AppTheme.subtleTextColor)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.emergencyColor),
                                  onPressed: () => _deleteContact(name),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      ),
    );
  }
}
