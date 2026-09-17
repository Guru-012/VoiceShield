import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<Map<String, dynamic>> processAudio(String audioPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/audio/process'),
      );

      if (kIsWeb) {
        // On Chrome, the recorder returns a blob URL.
        final response = await http.get(Uri.parse(audioPath));

        if (response.statusCode != 200) {
          throw Exception('Could not read recorded audio.');
        }

        final Uint8List audioBytes = response.bodyBytes;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioBytes,
            filename: 'voiceshield_recording.wav',
          ),
        );
      } else {
        // Android/Windows/iOS/etc. use a local file path.
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            audioPath,
            filename: 'voiceshield_recording.wav',
          ),
        );
      }

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Audio processing failed (${response.statusCode}): ${response.body}',
        );
      }

      return {
        'success': true,
        'data': response.body,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}