import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login_screen.dart';
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
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZoomIn(
                duration: const Duration(seconds: 1),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 80,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(seconds: 1),
                delay: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    Text(
                      'SOS GUARDIAN',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'YOUR VIRTUAL PROTECTOR',
                      style: TextStyle(
                        color: AppTheme.subtleTextColor,
                        letterSpacing: 2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
              FadeIn(
                duration: const Duration(seconds: 2),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
