import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis_result.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.0.6:8000';

  static const String _historyStorageKey =
      'voiceshield_local_analysis_history';

  // ================================================================
  // BACKEND HEALTH
  // ================================================================

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/health'),
          )
          .timeout(
            const Duration(seconds: 5),
          );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ================================================================
  // GET HISTORY
  // ================================================================

  Future<List<Map<String, dynamic>>> getHistory() async {
    List<Map<String, dynamic>> backendHistory = [];

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/history'),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          backendHistory = decoded
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        } else if (decoded is Map &&
            decoded['data'] is List) {
          backendHistory = (decoded['data'] as List)
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      }
    } catch (e) {
      print('Backend history unavailable: $e');
    }

    // Get locally saved analyses.
    final localHistory = await _getLocalHistory();

    // Combine backend + local history.
    final combined = <Map<String, dynamic>>[
      ...localHistory,
      ...backendHistory,
    ];

    // Remove duplicates.
    final unique = <String, Map<String, dynamic>>{};

    for (final item in combined) {
      final key = _historyKey(item);

      if (!unique.containsKey(key)) {
        unique[key] = item;
      }
    }

    final result = unique.values.toList();

    // Newest first.
    result.sort(
      (a, b) {
        final aTime =
            a['analyzed_at']?.toString() ??
            a['created_at']?.toString() ??
            '';

        final bTime =
            b['analyzed_at']?.toString() ??
            b['created_at']?.toString() ??
            '';

        return bTime.compareTo(aTime);
      },
    );

    return result;
  }

  // ================================================================
  // GET LOCAL HISTORY
  // ================================================================

  Future<List<Map<String, dynamic>>> _getLocalHistory() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final stored =
          prefs.getStringList(_historyStorageKey);

      if (stored == null || stored.isEmpty) {
        return [];
      }

      final history = <Map<String, dynamic>>[];

      for (final item in stored) {
        try {
          final decoded = jsonDecode(item);

          if (decoded is Map) {
            history.add(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {
          // Ignore malformed history item.
        }
      }

      return history;
    } catch (e) {
      print('Local history read error: $e');
      return [];
    }
  }

  // ================================================================
  // SAVE ANALYSIS TO LOCAL HISTORY
  // ================================================================

  Future<void> _saveLocalHistory(
    Map<String, dynamic> analysis,
  ) async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final existing =
          await _getLocalHistory();

      // Put newest analysis first.
      existing.insert(0, analysis);

      // Remove duplicates.
      final unique =
          <String, Map<String, dynamic>>{};

      for (final item in existing) {
        final key = _historyKey(item);

        if (!unique.containsKey(key)) {
          unique[key] = item;
        }
      }

      // Keep latest 50 analyses.
      final limited =
          unique.values.take(50).toList();

      final encoded = limited
          .map(
            (item) => jsonEncode(item),
          )
          .toList();

      await prefs.setStringList(
        _historyStorageKey,
        encoded,
      );

      print(
        'VoiceShield: analysis saved to local history.',
      );
    } catch (e) {
      print(
        'Local history save error: $e',
      );
    }
  }

  // ================================================================
  // CREATE UNIQUE HISTORY KEY
  // ================================================================

  String _historyKey(
    Map<String, dynamic> item,
  ) {
    final id =
        item['id'] ??
        item['analysis_id'];

    if (id != null) {
      return 'id_$id';
    }

    final filename =
        item['filename'] ??
        item['file_name'] ??
        'audio';

    final timestamp =
        item['analyzed_at'] ??
        item['created_at'] ??
        '';

    final riskScore =
        item['risk_score'] ??
        '';

    // IMPORTANT:
    // ${timestamp} prevents Dart from reading
    // "timestamp_" as a variable name.
    return '${filename}_${timestamp}_$riskScore';
  }

  // ================================================================
  // ANALYZE AUDIO BYTES
  // ================================================================

  Future<AnalysisResult> analyzeAudioBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/analyze'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse =
          await request.send();

      final responseBody =
          await streamedResponse.stream
              .bytesToString();

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        final decoded =
            jsonDecode(responseBody);

        if (decoded is Map) {
          Map<String, dynamic> analysisData;

          // Backend response:
          // { "data": {...} }
          if (decoded['data'] is Map) {
            analysisData =
                Map<String, dynamic>.from(
              decoded['data'] as Map,
            );
          } else {
            analysisData =
                Map<String, dynamic>.from(
              decoded,
            );
          }

          // Make sure filename exists.
          analysisData['filename'] ??=
              filename;

          // Add timestamp if backend doesn't provide one.
          analysisData['analyzed_at'] ??=
              DateTime.now()
                  .toIso8601String();

          // Save successful analysis locally.
          await _saveLocalHistory(
            analysisData,
          );

          return AnalysisResult.fromJson(
            analysisData,
          );
        }

        throw Exception(
          'Invalid response received from server.',
        );
      }

      throw Exception(
        'Server returned '
        '${streamedResponse.statusCode}: '
        '$responseBody',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // ================================================================
  // AUDIO PREPROCESSING
  // ================================================================

  Future<Map<String, dynamic>> processAudio(
    String filePath,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/audio/process'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
        ),
      );

      final streamedResponse =
          await request.send();

      final responseBody =
          await streamedResponse.stream
              .bytesToString();

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        final decoded =
            jsonDecode(responseBody);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        if (decoded is Map) {
          return Map<String, dynamic>.from(
            decoded,
          );
        }

        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'error':
            'Server returned '
            '${streamedResponse.statusCode}: '
            '$responseBody',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}