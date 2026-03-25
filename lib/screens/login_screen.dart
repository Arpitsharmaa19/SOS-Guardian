import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_screen.dart';
import 'home_screen.dart';
import 'police_dashboard_screen.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _selectedRole = 'citizen'; // Default
  bool _obscurePassword = true;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      // --- MASTER HQ BYPASS (Rule-Free) ---
      if (_selectedRole == 'police') {
        if (_passwordController.text == 'police123') {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PoliceDashboardScreen()),
          );
          return;
        } else {
           throw "Invalid HQ Credentials";
        }
      }

      // Standard Citizen Login (Firebase)
      final String email = _emailController.text.trim();
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );
      
      if (!mounted) return;
      
      // Fetch user role
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).get();
      final role = userDoc.data()?['role'] ?? 'citizen';

      if (role == 'police') {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppTheme.emergencyColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email first")),
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          // 🛡️ SECURITY GRID BACKGROUND
          Container(
            decoration: AppTheme.gradientBackground,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: LoginGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(maxWidth: isWeb ? 450 : double.infinity),
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO / SHIELD
                    FadeInDown(
                      duration: const Duration(seconds: 1),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 60,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        children: [
                          Text(
                            'SOS GUARDIAN',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ELITE COMMAND ACCESS',
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
                    const SizedBox(height: 50),
                    
                    // ROLE SELECTION
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _roleChip('CITIZEN', 'citizen', Icons.person_rounded),
                            _roleChip('POLICE HQ', 'police', Icons.admin_panel_settings_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // LOGIN FORM
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: Column(
                        children: [
                          if (_selectedRole == 'citizen') ...[
                            _buildInputField(
                              controller: _emailController,
                              label: 'IDENTIFIER (EMAIL)',
                              icon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildInputField(
                            controller: _passwordController,
                            label: 'ACCESS KEY (PASSWORD)',
                            icon: Icons.vpn_key_rounded,
                            isPassword: true,
                          ),
                          
                          if (_selectedRole == 'citizen')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: const Text(
                                  'FORGOT KEY?',
                                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 40),
                          
                          _isLoading
                            ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                            : SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 20,
                                    shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                                  ),
                                  child: const Text('AUTHORIZE', style: TextStyle(letterSpacing: 2)),
                                ),
                              ),
                          
                          const SizedBox(height: 40),
                          
                          if (_selectedRole == 'citizen')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("NEW GUARDIAN?", style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())),
                                  child: const Text('REGISTER HERE', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w900)),
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

class LoginGridPainter extends CustomPainter {
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

