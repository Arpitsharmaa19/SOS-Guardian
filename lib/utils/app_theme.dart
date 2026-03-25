import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- CORE PALETTE ---
  static const Color primaryColor = Color(0xFF00D4FF); // Electric Cyan
  static const Color secondaryColor = Color(0xFF6366F1); // Indigo Glow
  static const Color emergencyColor = Color(0xFFFF3131); // Neon Red
  static const Color backgroundColor = Color(0xFF040608); // Deep Space Black
  static const Color cardColor = Color(0xFF111827); // Dark Slate 900
  static const Color sleekGrey = Color(0xFF1F2937); // Glass Background
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color subtleTextColor = Color(0xFF94A3B8);

  // --- PREMIUM DECORATIONS ---
  static BoxDecoration glassDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
  );

  static BoxDecoration emergencyGlow = BoxDecoration(
    color: emergencyColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: emergencyColor.withOpacity(0.3), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: emergencyColor.withOpacity(0.1),
        blurRadius: 20,
        spreadRadius: 2,
      )
    ],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    textTheme: GoogleFonts.outfitTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: textColor,
        letterSpacing: 1.2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.all(20),
      labelStyle: const TextStyle(color: subtleTextColor, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Colors.white24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  static BoxDecoration gradientBackground = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0A0F1D), backgroundColor],
    ),
  );
}
