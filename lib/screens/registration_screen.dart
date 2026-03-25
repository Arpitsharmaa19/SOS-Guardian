import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'police_dashboard_screen.dart';
import '../utils/app_theme.dart';
import '../utils/api_config.dart';

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
  bool _isLoading = false;
  String _selectedRole = 'citizen'; // Default
  bool _obscurePassword = true;

  void _register() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _phoneController.text.trim();

    // --- ROLE-BASED VALIDATION ---
    if (_selectedRole == 'police') {
      _showError('Only System Admin can register new HQ accounts.');
      return;
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      _showError('All fields are required');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': 'citizen',
          'bloodType': 'N/A', // Default values
          'address': 'N/A',
          'photoUrl': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('mongo_user_id', data['userId']);
        await prefs.setString('user_name', name);
        await prefs.setString('user_email', email);
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_codeword', 'help me');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? "Registration Failed";
        throw error;
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
