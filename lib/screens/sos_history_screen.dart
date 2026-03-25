import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/api_config.dart';
import '../utils/app_theme.dart';

class SOSHistoryScreen extends StatefulWidget {
  const SOSHistoryScreen({super.key});

  @override
  State<SOSHistoryScreen> createState() => _SOSHistoryScreenState();
}

class _SOSHistoryScreenState extends State<SOSHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('mongo_user_id');
    
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse(ApiConfig.myHistoryUrl(userId)));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _history = data['history'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
     // Remote clearing can be implemented later
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
                painter: HistoryGridPainter(),
                size: Size.infinite,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : _history.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final data = _history[index] as Map<String, dynamic>;
                            final DateTime timestamp = data['timestamp'] != null 
                                ? DateTime.parse(data['timestamp']) 
                                : DateTime.now();
                            final String type = data['emotion'] ?? 'SOS ALERT';
                            
                            String emotionEmoji = '🚨';
                            if (type.contains('Terror')) emotionEmoji = '😱';
                            else if (type.contains('Anger')) emotionEmoji = '🛑';
                            else if (type.contains('Pain')) emotionEmoji = '🤕';
                            else if (type.contains('Sadness') || type.contains('Hiding')) emotionEmoji = '🤫';
                            else if (type.contains('Distress')) emotionEmoji = '🆘';

                            return FadeInUp(
                              duration: Duration(milliseconds: 200 + (index * 50)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: AppTheme.glassDecoration,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.emergencyColor.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppTheme.emergencyColor.withOpacity(0.1)),
                                        ),
                                        child: Text(emotionEmoji, style: const TextStyle(fontSize: 22)),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'SOS REPORT',
                                                  style: GoogleFonts.outfit(
                                                    color: AppTheme.emergencyColor,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('HH:mm').format(timestamp),
                                                  style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              type.toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(timestamp).toUpperCase(),
                                              style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
            'LOG ARCHIVE',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),
          GestureDetector(
            onTap: _clearHistory,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.emergencyColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emergencyColor.withOpacity(0.1)),
              ),
              child: const Icon(Icons.delete_sweep_rounded, size: 22, color: AppTheme.emergencyColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Icon(Icons.folder_off_outlined, size: 60, color: Colors.white10),
          ),
          const SizedBox(height: 24),
          Text(
            'ARCHIVE EMPTY',
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          const Text(
            'NO INCIDENT DATA RECORDED ON THIS UNIT.',
            style: TextStyle(color: Colors.white10, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class HistoryGridPainter extends CustomPainter {
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
