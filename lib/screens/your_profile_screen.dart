import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';

class YourProfileScreen extends StatefulWidget {
  const YourProfileScreen({super.key});

  @override
  State<YourProfileScreen> createState() => _YourProfileScreenState();
}

class _YourProfileScreenState extends State<YourProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  String _profileImageBase64 = '';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _nameController.text = prefs.getString('user_name') ?? '';
      _emailController.text = prefs.getString('user_email') ?? '';
      _contactController.text = prefs.getString('user_phone') ?? '';
      _addressController.text = prefs.getString('user_address') ?? '';
      _bloodTypeController.text = prefs.getString('user_blood') ?? '';
      _profileImageBase64 = prefs.getString('user_photo') ?? '';

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load profile locally', AppTheme.emergencyColor);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setString('user_phone', _contactController.text.trim());
      await prefs.setString('user_address', _addressController.text.trim());
      await prefs.setString('user_blood', _bloodTypeController.text.trim().toUpperCase());
      await prefs.setString('user_photo', _profileImageBase64);

      _showSnackBar('Identity updated locally', Colors.green);
    } catch (e) {
      _showSnackBar('Update failed', AppTheme.emergencyColor);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200, // Small for Base64 storage
        maxHeight: 200,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      _showSnackBar('Could not pick image: $e', AppTheme.emergencyColor);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
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
                painter: ProfileGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : Column(
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  FadeInDown(
                                    child: Center(
                                      child: Stack(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 2),
                                            ),
                                            child: CircleAvatar(
                                              radius: 65,
                                              backgroundColor: Colors.white.withOpacity(0.05),
                                              backgroundImage: _profileImageBase64.isNotEmpty 
                                                  ? MemoryImage(base64Decode(_profileImageBase64)) 
                                                  : null,
                                              child: _profileImageBase64.isEmpty 
                                                  ? const Icon(Icons.person_rounded, size: 70, color: Colors.white24)
                                                  : null,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 5,
                                            right: 5,
                                            child: GestureDetector(
                                              onTap: _pickImage,
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: const BoxDecoration(
                                                  color: AppTheme.primaryColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.black),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'GUARDIAN IDENTITY',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  FadeInUp(
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: AppTheme.glassDecoration,
                                      child: Column(
                                        children: [
                                          _buildField(
                                            controller: _nameController,
                                            label: 'FULL LEGAL NAME',
                                            icon: Icons.person_outline_rounded,
                                            validator: (v) => v!.isEmpty ? 'Name required' : null,
                                          ),
                                          const SizedBox(height: 24),
                                          _buildField(
                                            controller: _emailController,
                                            label: 'SECURE EMAIL (LOCKED)',
                                            icon: Icons.shield_outlined,
                                            readOnly: true,
                                          ),
                                          const SizedBox(height: 24),
                                          _buildField(
                                            controller: _contactController,
                                            label: 'PHONE NUMBER',
                                            icon: Icons.phone_android_rounded,
                                            keyboardType: TextInputType.phone,
                                          ),
                                          const SizedBox(height: 24),
                                          _buildField(
                                            controller: _addressController,
                                            label: 'PERMANENT ADDRESS',
                                            icon: Icons.home_outlined,
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 24),
                                          _buildField(
                                            controller: _bloodTypeController,
                                            label: 'BLOOD TYPE (EMERGENCY ONLY)',
                                            icon: Icons.bloodtype_outlined,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 200),
                                    child: _isSaving
                                        ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                                        : SizedBox(
                                            width: double.infinity,
                                            height: 60,
                                            child: ElevatedButton(
                                              onPressed: _saveProfile,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryColor,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              ),
                                              child: const Text('UPDATE IDENTITY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
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
            'MY PROFILE',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(width: 40), // Placeholder to center text
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(
          color: readOnly ? AppTheme.subtleTextColor : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5))),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }
}

class ProfileGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5;
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
