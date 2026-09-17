import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real-time Voice Detection Result Data Structure for Phase 3 & Phase 4
class RealtimeDetectionData {
  final String sessionId;
  final int chunkIndex;
  final double aiProbability;
  final double authenticity;
  final double confidence;
  final String riskLevel;
  final bool isAiGenerated;
  final double rawAiProbability;
  final double rollingAiProbability;
  final bool threatAlertTriggered;
  final String voiceResult;
  final String displayTitle;
  final String transcript;
  final double contextScore;
  final List<String> indicators;
  final String timestamp;
  final bool isDevelopmentMode;

  RealtimeDetectionData({
    required this.sessionId,
    required this.chunkIndex,
    required this.aiProbability,
    required this.authenticity,
    required this.confidence,
    required this.riskLevel,
    required this.isAiGenerated,
    required this.rawAiProbability,
    required this.rollingAiProbability,
    required this.threatAlertTriggered,
    required this.voiceResult,
    required this.displayTitle,
    required this.transcript,
    required this.contextScore,
    required this.indicators,
    required this.timestamp,
    required this.isDevelopmentMode,
  });

  factory RealtimeDetectionData.fromJson(Map<String, dynamic> json) {
    return RealtimeDetectionData(
      sessionId: json['session_id'] ?? '',
      chunkIndex: json['chunk_index'] ?? 0,
      aiProbability: (json['ai_probability'] as num?)?.toDouble() ?? 0.0,
      authenticity: (json['authenticity'] as num?)?.toDouble() ?? 1.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] ?? 'DEV_MODE',
      isAiGenerated: json['is_ai_generated'] ?? false,
      rawAiProbability: (json['raw_ai_probability'] as num?)?.toDouble() ?? 0.0,
      rollingAiProbability: (json['rolling_ai_probability'] as num?)?.toDouble() ?? 0.0,
      threatAlertTriggered: json['threat_alert_triggered'] ?? false,
      voiceResult: json['voice_result'] ?? 'MODEL_NOT_CONNECTED',
      displayTitle: json['display_title'] ?? '',
      transcript: json['transcript'] ?? '',
      contextScore: (json['context_score'] as num?)?.toDouble() ?? 0.0,
      indicators: (json['indicators'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? '',
      isDevelopmentMode: json['is_development_mode'] ?? true,
    );
  }
}

/// Service handling live audio streaming WebSocket sessions for VoiceShield Phase 3.
class RealtimeVoiceService {
  final String serverHost; // e.g. "192.168.0.7:8000"
  String? _activeSessionId;
  WebSocketChannel? _streamChannel;
  bool _isStreaming = false;

  // Event Callbacks
  Function(RealtimeDetectionData data)? onDetectionResultReceived;
  Function(String errorMessage)? onErrorOccurred;
  Function(bool isActive)? onSessionStateChanged;

RealtimeVoiceService({this.serverHost = '192.168.29.137:8000'});
  String? get activeSessionId => _activeSessionId;
  bool get isStreaming => _isStreaming;

  /// Step 1: Create a real-time detection session on backend via REST API.
  Future<String?> createSession() async {
    try {
      final url = Uri.parse('http://$serverHost/api/realtime/session');
      final response = await http.post(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeSessionId = data['session_id'];
        return _activeSessionId;
      } else {
        onErrorOccurred?.call('Failed to initialize session. Server returned ${response.statusCode}');
        return null;
      }
    } catch (e) {
      onErrorOccurred?.call('Session connection error: $e');
      return null;
    }
  }

  /// Step 2: Establish WebSocket audio stream channel using session ID.
  Future<bool> startStreamingSession([String? customSessionId]) async {
    final sessionId = customSessionId ?? _activeSessionId ?? await createSession();

    if (sessionId == null) {
      onErrorOccurred?.call('No valid session ID available for streaming.');
      return false;
    }

    _activeSessionId = sessionId;

    try {
      final wsUrl = Uri.parse('ws://$serverHost/api/ws/realtime/stream/$sessionId');
      _streamChannel = WebSocketChannel.connect(wsUrl);
      _isStreaming = true;
      onSessionStateChanged?.call(true);

      _streamChannel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> msg = jsonDecode(message);
            final type = msg['type'];

            if (type == 'realtime_detection_update' && msg['data'] != null) {
              final result = RealtimeDetectionData.fromJson(Map<String, dynamic>.from(msg['data']));
              onDetectionResultReceived?.call(result);
            } else if (type == 'error') {
              onErrorOccurred?.call(msg['message'] ?? 'Streaming error');
            }
          } catch (_) {}
        },
        onError: (err) {
          _isStreaming = false;
          onSessionStateChanged?.call(false);
          onErrorOccurred?.call('WebSocket connection error: $err');
        },
        onDone: () {
          _isStreaming = false;
          onSessionStateChanged?.call(false);
        },
      );

      return true;
    } catch (e) {
      _isStreaming = false;
      onSessionStateChanged?.call(false);
      onErrorOccurred?.call('Failed to connect streaming WebSocket: $e');
      return false;
    }
  }

  /// Step 3: Stream short raw 16-bit 16kHz PCM audio chunk bytes to backend over WebSocket.
  void sendAudioChunk(Uint8List pcmChunkBytes) {
    if (_streamChannel != null && _isStreaming) {
      _streamChannel!.sink.add(pcmChunkBytes);
    }
  }

  /// Step 4: Gracefully terminate streaming session.
  Future<void> stopSession() async {
    _isStreaming = false;
    onSessionStateChanged?.call(false);

    _streamChannel?.sink.close();
    _streamChannel = null;

    if (_activeSessionId != null) {
      try {
        final url = Uri.parse('http://$serverHost/api/realtime/session/$_activeSessionId');
        await http.delete(url).timeout(const Duration(seconds: 3));
      } catch (_) {}
      _activeSessionId = null;
    }
  }

  void dispose() {
    stopSession();
  }
}
