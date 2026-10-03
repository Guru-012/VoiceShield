import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCTestScreen extends StatefulWidget {
  const WebRTCTestScreen({super.key});

  @override
  State<WebRTCTestScreen> createState() =>
      _WebRTCTestScreenState();
}

class _WebRTCTestScreenState
    extends State<WebRTCTestScreen> {

  MediaStream? _localStream;

  bool _microphoneOn = false;

  Future<void> _startMicrophone() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      setState(() {
        _localStream = stream;
        _microphoneOn = true;
      });

      debugPrint('MICROPHONE STARTED');
    } catch (e) {
      debugPrint('MICROPHONE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone error: $e'),
        ),
      );
    }
  }

  Future<void> _stopMicrophone() async {
    final stream = _localStream;

    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }

      await stream.dispose();
    }

    setState(() {
      _localStream = null;
      _microphoneOn = false;
    });
  }

  @override
  void dispose() {
    _localStream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Test'),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _microphoneOn
                  ? Icons.mic
                  : Icons.mic_off,

              size: 80,

              color: _microphoneOn
                  ? Colors.green
                  : Colors.red,
            ),

            const SizedBox(height: 20),

            Text(
              _microphoneOn
                  ? 'Microphone is working'
                  : 'Microphone is OFF',

              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _microphoneOn
                  ? _stopMicrophone
                  : _startMicrophone,

              icon: Icon(
                _microphoneOn
                    ? Icons.stop
                    : Icons.mic,
              ),

              label: Text(
                _microphoneOn
                    ? 'STOP MICROPHONE'
                    : 'START MICROPHONE',
              ),
            ),
          ],
        ),
      ),
    );
  }
}