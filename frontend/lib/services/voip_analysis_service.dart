import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class VoIPAnalysisService {
  final String serverUrl;
  final String callId;
  final String clientId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Function(String)? onConnectionStateChanged;
  Function(Map<String, dynamic>)? onAnalysisUpdate;
  Function(String)? onError;

  VoIPAnalysisService({
    required this.serverUrl,
    required this.callId,
    required this.clientId,
  });

  // ============================================================
  // CONNECT
  // ============================================================

  Future<void> connect() async {
    try {
      onConnectionStateChanged?.call(
        'Connecting to VoiceShield analysis...',
      );

      final wsUrl =
          '$serverUrl/ws/voip/stream/$callId/$clientId';

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      await _channel!.ready;

      onConnectionStateChanged?.call(
        'VoiceShield analysis connected',
      );

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          onError?.call(
            'Analysis WebSocket error: $error',
          );
        },
        onDone: () {
          onConnectionStateChanged?.call(
            'VoiceShield analysis disconnected',
          );
        },
      );
    } catch (e) {
      onError?.call(
        'Could not connect to analysis server: $e',
      );
    }
  }

  // ============================================================
  // SEND AUDIO
  // ============================================================

  void sendAudio(Uint8List audioBytes) {
    if (_channel == null) {
      return;
    }

    try {
      _channel!.sink.add(audioBytes);
    } catch (e) {
      onError?.call(
        'Could not send audio for analysis: $e',
      );
    }
  }

  // ============================================================
  // RECEIVE ANALYSIS
  // ============================================================

  void _handleMessage(dynamic message) {
    try {
      if (message is! String) {
        return;
      }

      final decoded = jsonDecode(message);

      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == 'ai_threat_update') {
          final data = decoded['data'];

          if (data is Map) {
            onAnalysisUpdate?.call(
              Map<String, dynamic>.from(data),
            );
          }
        }
      }
    } catch (e) {
      onError?.call(
        'Invalid analysis response: $e',
      );
    }
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    onConnectionStateChanged?.call(
      'VoiceShield analysis disconnected',
    );
  }
}