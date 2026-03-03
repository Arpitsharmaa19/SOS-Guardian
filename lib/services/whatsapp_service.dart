import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppService {
  // Replace this URL after deploying to Render
  // Example: https://sos-guardian-backend.onrender.com
  static const String _baseUrl = 'YOUR_RENDER_URL_HERE';

  static Future<void> sendWhatsAppAlert(String phoneNumber, String message) async {
    if (_baseUrl == 'YOUR_RENDER_URL_HERE') {
      print('WhatsApp alert skipped: Render URL not configured');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-whatsapp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': phoneNumber,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        print('WhatsApp Alert Sent successfully to $phoneNumber');
      } else {
        print('Failed to send WhatsApp: ${response.body}');
      }
    } catch (e) {
      print('Error calling WhatsApp backend: $e');
    }
  }
}
