import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class WhatsAppService {
  // Email Alert functionality removed per user request
  static Future<void> sendEmailAlert(String email, String message) async {
    print('📧 SOS_SERVICE: Email Alert skipped (Pure MongoDB Architecture)');
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
    // Note: Emotion analysis is now performed server-side during the 'report-sos' cycle.
    // This method is maintained for backward compatibility in HomeScreen.
    return {'emotion': 'Urgent Alarm'}; 
  }
}
