import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class WhatsAppService {
  static Future<void> sendEmailAlert(String email, String message) async {
    try {
      print('🚀 SOS_SERVICE: Attempting Email to ${ApiConfig.sendEmailUrl} for $email');
      final response = await http.post(
        Uri.parse(ApiConfig.sendEmailUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': email,
          'message': message,
          'subject': '🚨 EMERGENCY: SOS GUARDIAN ALERT 🚨'
        }),
      );

      if (response.statusCode == 200) {
        print('✅ SUCCESS: Email Alert Sent to $email');
      } else {
        print('❌ ERROR: Backend returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ CRITICAL: Could not reach Email backend: $e');
    }
  }

  static Future<void> makeVoiceCall(String phoneNumber, String message) async {
    try {
      print('🚀 SOS_SERVICE: Attempting Call to ${ApiConfig.makeCallUrl} for $phoneNumber');
      final response = await http.post(
        Uri.parse(ApiConfig.makeCallUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': phoneNumber.replaceAll(' ', '').replaceAll('-', ''),
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ SUCCESS: Voice Call Initiated to $phoneNumber');
      } else {
        print('❌ ERROR: Backend returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ CRITICAL: Could not reach voice call backend: $e');
    }
  }

  static Future<void> sendSMSAlert(String phoneNumber, String message) async {
    try {
      print('🚀 SOS_SERVICE: Attempting SMS to ${ApiConfig.sendSmsUrl} for $phoneNumber');
      final response = await http.post(
        Uri.parse(ApiConfig.sendSmsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': phoneNumber.replaceAll(' ', '').replaceAll('-', ''),
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ SUCCESS: SMS Alert Sent to $phoneNumber');
      } else {
        print('❌ ERROR: Backend returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ CRITICAL: Could not reach SMS backend: $e');
    }
  }

  static Future<Map<String, dynamic>?> analyzeEmotion(String message, [String? codeword, double? soundLevel]) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.analyzeEmotionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'codeword': codeword,
          'soundLevel': soundLevel ?? 40.0,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Emotion analysis error: $e');
    }
    return null;
  }
}
