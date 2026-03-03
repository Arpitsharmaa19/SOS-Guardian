// import 'package:flutter_vosk/flutter_vosk.dart';


// class VoiceService {
//   final VoskRecognizer _recognizer = VoskRecognizer(modelPath: 'assets/models/vosk-model');

//   // static const platform = MethodChannel('voice_service');

//   // Future<String> startListening() async {
//   //   try {
//   //     final String result = await platform.invokeMethod('startListening');
//   //     return result;
//   //   } on PlatformException catch (e) {
//   //     return "Failed to listen: '${e.message}'.";
//   //   }
//   // }

//   Future<void> initialize() async {
//     try {
//       await _recognizer.initialize();
//     } catch (e) {
//       throw Exception('Error initializing voice recognizer: $e');
//     }
//   }

//   Future<void> startListening(Function(String) onResult) async {
//     try {
//       _recognizer.onResult.listen((result) {
//         onResult(result.text);
//       });
//       await _recognizer.start();
//     } catch (e) {
//       throw Exception('Error starting voice recognition: $e');
//     }
//   }

//   Future<void> stopListening() async {
//     try {
//       await _recognizer.stop();
//     } catch (e) {
//       throw Exception('Error stopping voice recognition: $e');
//     }
//   }
// }

import 'package:flutter/services.dart';

class VoiceService {
  static const platform = MethodChannel('voice_service');

  Future<String> startListening() async {
    try {
      final String result = await platform.invokeMethod('startListening');
      return result;
    } on PlatformException catch (e) {
      return "Failed to listen: '${e.message}'.";
    }
  }
}
