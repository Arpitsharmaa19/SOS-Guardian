import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'police_dashboard_screen.dart';
import '../utils/app_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedRole = 'citizen'; // Default

  void _register() async {
    // --- ROLE-BASED VALIDATION ---
    bool isInvalid = _nameController.text.isEmpty || _passwordController.text.isEmpty;
    if (_selectedRole == 'citizen') {
      if (_emailController.text.isEmpty) isInvalid = true;
    }

    if (isInvalid) {
      _showError('All fields are required');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create the Auth user FIRST to satisfy "Auth Required" rules
      final newUser = await _auth.createUserWithEmailAndPassword(
        email: _selectedRole == 'police' ? 'police_hq@sosguardian.com' : _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (newUser.user != null) {
        // 2. NOW check for the Unique Police Role while logged in
        if (_selectedRole == 'police') {
          final existingPolice = await _firestore.collection('users').where('role', isEqualTo: 'police').get();
          if (existingPolice.docs.isNotEmpty && existingPolice.docs.first.id != newUser.user!.uid) {
            await newUser.user!.delete(); // Cleanup if duplicate
            _showError('Error: A Master Police account already exists.');
            return;
          }
        }

        // 3. Save the document
        await _firestore.collection('users').doc(newUser.user!.uid).set({
          'uid': newUser.user!.uid,
          'name': _nameController.text.trim(),
          'email': newUser.user!.email,
          'phone': _selectedRole == 'police' ? 'N/A' : _phoneController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'contactList': {},
          'codeword': '',
        });

        if (!mounted) return;
        
        // Role-based navigation
        if (_selectedRole == 'police') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PoliceDashboardScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.emergencyColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  FadeInLeft(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInDown(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join SOS Guardian',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start your premium protection journey today',
                          style: TextStyle(
                            color: AppTheme.subtleTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: Column(
                      children: [
                          _buildInputField(
                            controller: _nameController,
                            label: _selectedRole == 'police' ? 'Officer / Dept Name' : 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          if (_selectedRole == 'citizen') ...[
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                          const SizedBox(height: 20),
                        _buildInputField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_open_rounded,
                          obscureText: true,
                        ),
                        const SizedBox(height: 30),
                        // ROLE SELECTION
                        Row(
                          children: [
                            const Text('REGISTER AS:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 15),
                            _roleChip('Citizen', 'citizen', Icons.person_outline),
                            const SizedBox(width: 10),
                            _roleChip('Police', 'police', Icons.shield_outlined),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _isLoading
                          ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                          : Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryColor.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                onPressed: _register,
                                child: const Text(
                                  'CREATE ACCOUNT',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already a member?",
                              style: TextStyle(color: AppTheme.subtleTextColor),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Login', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String label, String role, IconData icon) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.secondaryColor : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.secondaryColor),
      ),
    );
  }
}
