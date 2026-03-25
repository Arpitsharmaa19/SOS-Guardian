import 'package:google_fonts/google_fonts.dart';
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
  final _emailController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic> _contacts = {};
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
          _contacts = Map<String, dynamic>.from(doc.data()!['contactList']);
        });
      }
    }
  }

  void _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _emailController.text.isEmpty) {
      _showSnackBar('Provide name, number and email', AppTheme.emergencyColor);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Store as a nested map: { name: { phone: ..., email: ... } }
        final newContactData = {
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        };
        
        // Fetch current list
        final doc = await _firestore.collection('users').doc(user.uid).get();
        Map<String, dynamic> currentContacts = {};
        if (doc.exists && doc.data()!.containsKey('contactList')) {
          currentContacts = Map<String, dynamic>.from(doc.data()!['contactList']);
        }
        
        currentContacts[_nameController.text.trim()] = newContactData;

        await _firestore.collection('users').doc(user.uid).set({
          'contactList': currentContacts,
        }, SetOptions(merge: true));

        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
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
      body: Stack(
        children: [
          // 🛡️ SECURITY GRID BACKGROUND
          Container(
            decoration: AppTheme.gradientBackground,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: ContactGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        FadeInDown(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: AppTheme.glassDecoration,
                            child: Column(
                              children: [
                                _buildInputField(_nameController, 'CONTACT IDENTIFIER', Icons.person_add_alt_rounded),
                                const SizedBox(height: 16),
                                _buildInputField(_phoneController, 'SECURE PHONE NUMBER', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                                const SizedBox(height: 16),
                                _buildInputField(_emailController, 'SECURE EMAIL', Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 24),
                                _isLoading
                                  ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: _addContact,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: const Text('ADD TO CIRCLE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Container(width: 4, height: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Text(
                                'TRUSTED CIRCLE (${_contacts.length})',
                                style: GoogleFonts.outfit(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 2, 
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Expanded(
                          child: _contacts.isEmpty
                            ? Center(child: Text('NO GUARDIANS ADDED', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)))
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _contacts.length,
                                itemBuilder: (context, index) {
                                  String name = _contacts.keys.elementAt(index);
                                  dynamic data = _contacts[name];
                                  String phone = (data is Map) ? data['phone'] ?? '' : data.toString();
                                  String email = (data is Map) ? data['email'] ?? '' : '';
                                  
                                  return FadeInUp(
                                    delay: Duration(milliseconds: index * 100),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 24),
                                        ),
                                        title: Text(
                                          name.toUpperCase(), 
                                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            '$phone\n$email', 
                                            style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.emergencyColor, size: 22),
                                          onPressed: () => _deleteContact(name),
                                        ),
                                        isThreeLine: true,
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
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            ),
          ),
          Text(
            'GUARDIANS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class ContactGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5;
    const spacing = 45.0;
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
