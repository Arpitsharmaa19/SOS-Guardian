import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'police_dashboard_screen.dart';
import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user role for direct navigation
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print("❌ Navigation error in Splash: $e");
      // Fallback to login in case of any crash
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
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
                painter: SplashGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZoomIn(
                  duration: const Duration(seconds: 1),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 100,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: AppTheme.secondaryColor.withOpacity(0.2),
                          blurRadius: 50,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassDecoration.copyWith(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                FadeInUp(
                  duration: const Duration(seconds: 1),
                  delay: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text(
                        'SOS GUARDIAN',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ELITE SECURITY CONSOLE',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryColor,
                          letterSpacing: 4,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
                FadeIn(
                  duration: const Duration(seconds: 2),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SECURE CONNECTION...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplashGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5;
    const spacing = 60.0;
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
