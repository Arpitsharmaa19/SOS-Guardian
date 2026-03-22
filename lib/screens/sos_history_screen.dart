import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
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
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final String? historyString = prefs.getString('sos_history_local');
    if (historyString != null) {
      setState(() {
        _history = jsonDecode(historyString);
        _isLoading = false;
      });
    } else {
      setState(() {
        _history = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Clear All History?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all incident logs from this device.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Clear All', style: TextStyle(color: AppTheme.emergencyColor))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sos_history_local');
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _history.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final data = _history[index] as Map<String, dynamic>;
                        final DateTime timestamp = DateTime.parse(data['timestamp']);
                        final String type = data['type'] ?? 'Automated';
                        
                        // Map emotion keyword to emoji
                        String emotionEmoji = '🚨';
                        if (type.contains('Terror')) emotionEmoji = '😱';
                        else if (type.contains('Anger')) emotionEmoji = '🛑';
                        else if (type.contains('Pain')) emotionEmoji = '🤕';
                        else if (type.contains('Sadness') || type.contains('Despair')) emotionEmoji = '🤫';
                        else if (type.contains('Distress')) emotionEmoji = '🆘';

                        return FadeInUp(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emergencyColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.emergencyColor.withOpacity(0.2)),
                                  ),
                                  child: Text(emotionEmoji, style: const TextStyle(fontSize: 24)),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'SOS ALERT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('hh:mm a').format(timestamp),
                                            style: const TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        type,
                                        style: const TextStyle(color: AppTheme.subtleTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(timestamp),
                                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 10, right: 20, bottom: 30),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incident Logs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Stored safely on this device',
                  style: const TextStyle(
                    color: AppTheme.subtleTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.emergencyColor),
            onPressed: _clearHistory,
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
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 80, color: Colors.white10),
          ),
          const SizedBox(height: 24),
          const Text(
            'Secure & Clear',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'No local incidents recorded yet.',
            style: TextStyle(color: AppTheme.subtleTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
