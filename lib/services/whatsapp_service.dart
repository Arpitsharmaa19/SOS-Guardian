import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppService {
  // Use 127.0.0.1 for more reliable local connection in some environments
  static const String _baseUrl = 'http://127.0.0.1:3000';

  static Future<void> sendWhatsAppAlert(String phoneNumber, String message) async {
    try {
      print('DEBUG: Attempting to call backend at $_baseUrl/send-whatsapp for $phoneNumber');
      final response = await http.post(
        Uri.parse('$_baseUrl/send-whatsapp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': phoneNumber.replaceAll(' ', '').replaceAll('-', ''),
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ SUCCESS: WhatsApp Alert Sent to $phoneNumber');
      } else {
        print('❌ ERROR: Backend returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ CRITICAL: Could not reach WhatsApp backend: $e');
    }
  }
}
