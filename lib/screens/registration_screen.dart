import 'package:google_fonts/google_fonts.dart';
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
  bool _obscurePassword = true;

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
      body: Stack(
        children: [
          // 🛡️ SECURITY GRID BACKGROUND
          Container(
            decoration: AppTheme.gradientBackground,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: RegGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    FadeInLeft(
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'JOIN THE GUARDIANS',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 28,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'SECURE YOUR DIGITAL SHIELD TODAY',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
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
                            // ROLE SELECTION
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _roleChip('CITIZEN', 'citizen', Icons.person_rounded),
                                  _roleChip('POLICE', 'police', Icons.admin_panel_settings_rounded),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            _buildInputField(
                              controller: _nameController,
                              label: _selectedRole == 'police' ? 'OFFICER / DEPT NAME' : 'FULL LEGAL NAME',
                              icon: Icons.person_outline_rounded,
                            ),
                            if (_selectedRole == 'citizen') ...[
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _emailController,
                                label: 'IDENTIFIER (EMAIL)',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _phoneController,
                                label: 'SECURE PHONE NUMBER',
                                icon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                            const SizedBox(height: 20),
                          _buildInputField(
                            controller: _passwordController,
                            label: 'ACCESS KEY (PASSWORD)',
                            icon: Icons.vpn_key_rounded,
                            isPassword: true,
                          ),
                          const SizedBox(height: 40),
                          
                          _isLoading
                            ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                            : SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 20,
                                    shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                                  ),
                                  child: const Text('INITIALIZE ACCOUNT', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900)),
                                ),
                              ),
                              
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("ALREADY SECURED?", style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('LOGIN', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w900)),
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
        ],
      ),
    );
  }

  Widget _roleChip(String label, String role, IconData icon) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}

class RegGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15)..strokeWidth = 0.5;
    const spacing = 50.0;
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
