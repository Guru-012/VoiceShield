import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallConnectionTest extends StatefulWidget {
  const CallConnectionTest({super.key});

  @override
  State<CallConnectionTest> createState() =>
      _CallConnectionTestState();
}

class _CallConnectionTestState
    extends State<CallConnectionTest> {
  WebSocketChannel? _channel;

  String _status = 'Not connected';

  Future<void> _connect() async {
    // IMPORTANT:
    // Replace this IP with the same PC IPv4
    // you already put into call_service.dart.
    const serverIp = '192.168.0.6';

    // Temporary unique ID for this phone.
    const clientId = 'person_a';

    final url =
        'ws://$serverIp:8000/api/ws/voip/signal/$clientId';

    setState(() {
      _status = 'Connecting...';
    });

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(url),
      );

      _channel = channel;

      await channel.ready;

      setState(() {
        _status = '🟢 WebSocket Connected';
      });

      channel.stream.listen(
        (message) {
          debugPrint(
            'SERVER MESSAGE: $message',
          );
        },
        onError: (error) {
          setState(() {
            _status = '🔴 WebSocket error: $error';
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _status = '🟠 WebSocket disconnected';
            });
          }
        },
      );

      // Join a temporary room.
      channel.sink.add(
        jsonEncode({
          'type': 'join_room',
          'room_id': 'demo_room',
        }),
      );
    } catch (e) {
      setState(() {
        _status = '🔴 Connection failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VoiceShield Call Test',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_in_talk,
                size: 80,
              ),

              const SizedBox(height: 30),

              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _connect,
                child: const Text(
                  'TEST CALL CONNECTION',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}