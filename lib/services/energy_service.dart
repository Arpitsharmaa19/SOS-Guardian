import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EnergyTracker {
  static final EnergyTracker _instance = EnergyTracker._internal();
  factory EnergyTracker() => _instance;
  EnergyTracker._internal();

  // Power Consumption Constants (approximate mA)
  // These represent the typical draw for these sensors on modern smartphones
  static const double micActiveMA = 165.0; // Voice processing draw
  static const double gpsHighAccMA = 95.0;  // Satellite GPS draw
  static const double gpsBalancedMA = 35.0; // Cellular/Wi-Fi location
  static const double defaultBatteryCapacity = 4500.0; // 4500mAh typical battery

  bool _isTracking = false;
  bool _isOptimizedMode = false;
  
  DateTime? _sessionStartTime;
  
  Future<void> init() async {
    // Basic init if needed
  }

  void startTracking(bool isOptimized) {
    if (!_isTracking) {
      _isTracking = true;
      _isOptimizedMode = isOptimized;
      _sessionStartTime = DateTime.now();
    }
  }

  Future<void> stopTracking() async {
    if (_isTracking && _sessionStartTime != null) {
      final now = DateTime.now();
      final durationSeconds = now.difference(_sessionStartTime!).inSeconds;
      
      // Calculate energy for this session
      double ma = _isOptimizedMode ? (micActiveMA + gpsBalancedMA) : (micActiveMA + gpsHighAccMA);
      double mahConsumed = (ma * (durationSeconds / 3600.0));

      await _logSession(mahConsumed);
      
      _isTracking = false;
      _sessionStartTime = null;
    }
  }

  Future<void> _logSession(double mah) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList('energy_logs_v2') ?? [];
    
    final newLog = {
      't': DateTime.now().millisecondsSinceEpoch,
      'm': mah,
    };
    
    logs.add(jsonEncode(newLog));
    
    // Cleanup: Remove logs older than 24 hours
    final cutoff = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    logs = logs.where((l) {
      final data = jsonDecode(l);
      return data['t'] > cutoff;
    }).toList();

    await prefs.setStringList('energy_logs_v2', logs);
  }

  Future<Map<String, double>> get24HourMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList('energy_logs_v2') ?? [];
    
    double totalMah = 0.0;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    for (var l in logs) {
      final data = jsonDecode(l);
      if (data['t'] > cutoff) {
        totalMah += (data['m'] as num).toDouble();
      }
    }

    // Include current live session if tracking
    if (_isTracking && _sessionStartTime != null) {
      final durationSeconds = DateTime.now().difference(_sessionStartTime!).inSeconds;
      double ma = _isOptimizedMode ? (micActiveMA + gpsBalancedMA) : (micActiveMA + gpsHighAccMA);
      totalMah += (ma * (durationSeconds / 3600.0));
    }

    double batteryPercent = (totalMah / defaultBatteryCapacity) * 100;

    return {
      'totalMah': totalMah,
      'batteryPercent': batteryPercent,
    };
  }
}
