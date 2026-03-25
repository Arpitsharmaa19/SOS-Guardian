import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import '../utils/api_config.dart';
import '../utils/app_theme.dart';

class SetCodeWordScreen extends StatefulWidget {
  const SetCodeWordScreen({super.key});

  @override
  SetCodeWordScreenState createState() => SetCodeWordScreenState();
}

class SetCodeWordScreenState extends State<SetCodeWordScreen> {
  final _codeWordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCodeWord();
  }

  void _loadCurrentCodeWord() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _codeWordController.text = prefs.getString('user_codeword') ?? 'help me';
    });
  }

  void _saveCodeWord() async {
    final word = _codeWordController.text.trim().toLowerCase();
    if (word.isEmpty) {
      _showSnackBar('Please enter a codeword', AppTheme.emergencyColor);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('mongo_user_id');

      if (userId != null) {
        final response = await http.post(
          Uri.parse(ApiConfig.updateCodewordUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'codeword': word}),
        );
        
        if (response.statusCode == 200) {
          await prefs.setString('user_codeword', word);
          _showSnackBar('Codeword updated successfully', Colors.green);
          Navigator.pop(context);
        } else {
           throw "Update failed on server";
        }
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
      body: Stack(
        children: [
          // 🛡️ SECURITY GRID BACKGROUND
          Container(
            decoration: AppTheme.gradientBackground,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: CodeGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          FadeInDown(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: AppTheme.glassDecoration,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.psychology_rounded, size: 50, color: AppTheme.primaryColor),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'EMERGENCY TRIGGER',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'WHEN SPOKEN, THIS WORD ACTIVATES THE GLOBAL SOS NETWORK INSTANTLY.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                          FadeInUp(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                                      top: BorderSide(color: AppTheme.primaryColor.withOpacity(0.1), width: 1),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _codeWordController,
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.primaryColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                    ),
                                    textAlign: TextAlign.center,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'CODEWORD',
                                      hintStyle: TextStyle(color: Colors.white10, letterSpacing: 4),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  'CHOOSE A SIMPLE, CLEAR WORD',
                                  style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                                const SizedBox(height: 60),
                                _isLoading
                                  ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 60,
                                      child: ElevatedButton(
                                        onPressed: _saveCodeWord,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                        child: const Text('ENCRYPT & SAVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
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
             'SECURITY KEY',
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
}

class CodeGridPainter extends CustomPainter {
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
