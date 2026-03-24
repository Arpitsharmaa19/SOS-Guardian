import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/api_config.dart';

class PoliceDashboardScreen extends StatefulWidget {
  const PoliceDashboardScreen({super.key});

  @override
  State<PoliceDashboardScreen> createState() => _PoliceDashboardScreenState();
}

class _PoliceDashboardScreenState extends State<PoliceDashboardScreen> {
  List<dynamic> _activeEmergencies = [];
  List<dynamic> _historyEmergencies = [];
  Timer? _refreshTimer;
  bool _isFetching = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    // Streams handle fetching automatically
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // These are replaced by StreamBuilders for a better reactive UI

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(url)) throw 'Could not launch $url';
  }

  Future<void> _resolveSOS(String reportId) async {
    try {
      await FirebaseFirestore.instance.collection('sos_reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      
      // Also notify backend if needed for SMS deactivation/cleanup
      http.post(
        Uri.parse(ApiConfig.hqResolveUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reportId': reportId}), 
      ).catchError((e) => debugPrint("Backend resolve notify error: $e"));

    } catch (e) {
      debugPrint("Resolve Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMMAND CENTER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('SYSTEM LIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white54), onPressed: _logout),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Column(
          children: [
            _buildStatBar(),
            _buildToggle(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sos_reports')
                    .where('status', isEqualTo: _showHistory ? 'resolved' : 'active')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final reports = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                  return _buildEmergencyList(reports);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            _toggleItem('LIVE DISPATCH', !_showHistory),
            _toggleItem('INCIDENT LOGS', _showHistory),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String title, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showHistory = !isActive ? !_showHistory : _showHistory),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: isActive ? Border.all(color: Colors.blueAccent.withOpacity(0.5)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sos_reports').snapshots(),
      builder: (context, snapshot) {
        int active = 0;
        int resolved = 0;
        if (snapshot.hasData) {
          active = snapshot.data!.docs.where((doc) => doc['status'] == 'active').length;
          resolved = snapshot.data!.docs.where((doc) => doc['status'] == 'resolved').length;
        }

        return Container(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
          child: FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Row(
              children: [
                _statItem('ACTIVE SOS', active.toString(), Colors.redAccent),
                const SizedBox(width: 12),
                _statItem('RESOLVED', resolved.toString(), Colors.greenAccent),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_showHistory ? Icons.history_rounded : Icons.radar_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          Text(_showHistory ? 'NO PAST LOGS FOUND' : 'SCANNING FOR SIGNALS...', 
               style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildEmergencyList(List<dynamic> list) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final data = list[index];
        bool isMedical = data['emotion'].toString().toLowerCase().contains('medical');
        Color cardColor = isMedical ? Colors.orangeAccent : Colors.redAccent;
        if (_showHistory) cardColor = Colors.greenAccent;

        return FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardColor.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PROFILE PHOTO
                        Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardColor.withOpacity(0.5), width: 2),
                            image: data['userPhoto'] != null && data['userPhoto'].toString().isNotEmpty
                                ? DecorationImage(image: MemoryImage(base64Decode(data['userPhoto'])), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (data['userPhoto'] == null || data['userPhoto'].toString().isEmpty)
                              ? Icon(Icons.person_rounded, color: cardColor, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(data['userName']?.toUpperCase() ?? 'UNKNOWN VICTIM', 
                                       style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  const Spacer(),
                                  _badge(_showHistory ? 'RESOLVED' : 'URGENT', cardColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.bloodtype_rounded, size: 14, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text('BLOOD: ${data['userBlood'] ?? 'N/A'}', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.phone_rounded, size: 14, color: Colors.white30),
                                  const SizedBox(width: 4),
                                  Text(data['userPhone'] ?? 'N/A', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ADDRESS BLOCK
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PERMANENT ADDRESS', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(data['userAddress'] ?? 'No fixed address provided', 
                               style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('SITUATION: ${data['emotion'] ?? 'UNKNOWN'}', 
                         style: TextStyle(color: cardColor, fontSize: 13, fontWeight: FontWeight.w900)),
                    const Divider(color: Colors.white10, height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openMap(data['lat'], data['lng']),
                            icon: Icon(_showHistory ? Icons.map_rounded : Icons.near_me_rounded, size: 16),
                            label: Text(_showHistory ? 'VIEW INCIDENT LOCATION' : 'TRACK LIVE', style: const TextStyle(fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cardColor,
                              foregroundColor: Colors.white.withOpacity(0.9),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (!_showHistory) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                            onPressed: () => _resolveSOS(data['reportId'] ?? data['userId']),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}
