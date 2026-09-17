import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'theme/app_theme.dart';
import 'screens/analysis_screen.dart';

class RecordVoiceScreen extends StatefulWidget {
  const RecordVoiceScreen({super.key});

  @override
  State<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

class _RecordVoiceScreenState extends State<RecordVoiceScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isAnalyzing = false;

  String? _recordedPath;
  int _seconds = 0;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ============================================================
  // START RECORDING
  // ============================================================

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required.'),
          ),
        );
      }
      return;
    }

    // Get a real writable directory on the phone.
    final directory = await getTemporaryDirectory();

    final path =
        '${directory.path}/voiceshield_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    debugPrint('Recording file path: $path');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    if (mounted) {
      setState(() {
        _isRecording = true;
        _recordedPath = null;
        _seconds = 0;
      });
    }

    _runTimer();
  }

  // ============================================================
  // RECORDING TIMER
  // ============================================================

  void _runTimer() async {
    while (_isRecording) {
      await Future.delayed(const Duration(seconds: 1));

      if (!_isRecording) {
        break;
      }

      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    }
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();

    debugPrint('Recording stopped.');
    debugPrint('Saved recording path: $path');

    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording file could not be created.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    }
  }

  // ============================================================
  // PLAY RECORDING
  // ============================================================

  Future<void> _playRecording() async {
    if (_recordedPath == null) {
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    try {
      if (kIsWeb ||
          _recordedPath!.startsWith('blob:') ||
          _recordedPath!.startsWith('http')) {
        await _player.play(
          UrlSource(_recordedPath!),
        );
      } else {
        await _player.play(
          DeviceFileSource(_recordedPath!),
        );
      }
    } catch (e) {
      debugPrint('Playback error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback failed: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  // ============================================================
  // DELETE RECORDING
  // ============================================================

  void _deleteRecording() {
    setState(() {
      _recordedPath = null;
      _seconds = 0;
    });
  }

  // ============================================================
  // ANALYZE VOICE
  // ============================================================

  Future<void> _analyzeVoice() async {
    if (_recordedPath == null || _recordedPath!.isEmpty) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      Uint8List bytes;

      // ----------------------------------------------------------
      // WEB
      // ----------------------------------------------------------

      if (kIsWeb ||
          _recordedPath!.startsWith('blob:') ||
          _recordedPath!.startsWith('http')) {
        final uri = Uri.parse(_recordedPath!);

        final response = await http.get(uri);

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to read recorded audio from browser storage.',
          );
        }

        bytes = response.bodyBytes;
      }

      // ----------------------------------------------------------
      // ANDROID / IOS / WINDOWS
      // ----------------------------------------------------------

      else {
        final file = File(_recordedPath!);

        debugPrint('Checking recording file...');
        debugPrint('Path: ${file.path}');

        final exists = await file.exists();

        debugPrint('File exists: $exists');

        if (!exists) {
          throw Exception(
            'Recorded audio file was not found on the device.',
          );
        }

        bytes = await file.readAsBytes();

        debugPrint(
          'Successfully read recording: ${bytes.length} bytes',
        );
      }

      // ----------------------------------------------------------
      // CHECK AUDIO
      // ----------------------------------------------------------

      if (bytes.isEmpty) {
        throw Exception(
          'Recorded audio file is empty.',
        );
      }

      debugPrint(
        'Audio ready for analysis: ${bytes.length} bytes',
      );

      // Give the backend a proper WAV filename.
      final filename =
          'voiceshield_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
      });

      // ----------------------------------------------------------
      // OPEN ANALYSIS SCREEN
      // ----------------------------------------------------------

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            audioBytes: bytes,
            filename: filename,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Audio analysis error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audio processing failed: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  // ============================================================
  // FORMAT TIMER
  // ============================================================

  String _formatTime() {
    final minutes =
        (_seconds ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (_seconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Voice'),
        centerTitle: true,
      ),

      body: SizedBox(
        width: double.infinity,
        height: double.infinity,

        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  // MIC ICON
                  Icon(
                    _isRecording
                        ? Icons.mic
                        : Icons.mic_none,
                    size: 80,
                  ),

                  const SizedBox(height: 24),

                  // TIMER
                  Text(
                    _formatTime(),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // STATUS
                  Text(
                    _isRecording
                        ? 'Recording your voice...'
                        : _recordedPath != null
                            ? 'Recording completed'
                            : 'Tap the button to start',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // START / STOP
                  if (_isRecording)
                    ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop),
                      label: const Text(
                        'STOP RECORDING',
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text(
                        'START RECORDING',
                      ),
                    ),

                  const SizedBox(height: 20),

                  // AFTER RECORDING
                  if (_recordedPath != null) ...[
                    // PLAY
                    ElevatedButton.icon(
                      onPressed:
                          _isPlaying ? null : _playRecording,
                      icon: const Icon(
                        Icons.play_arrow,
                      ),
                      label: Text(
                        _isPlaying
                            ? 'PLAYING...'
                            : 'PLAY RECORDING',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // DELETE
                    TextButton.icon(
                      onPressed: _deleteRecording,
                      icon: const Icon(
                        Icons.delete,
                      ),
                      label: const Text(
                        'DELETE & RECORD AGAIN',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ANALYZE
                    ElevatedButton.icon(
                      onPressed: _isAnalyzing
                          ? null
                          : _analyzeVoice,
                      icon: const Icon(
                        Icons.security,
                      ),
                      label: Text(
                        _isAnalyzing
                            ? 'ANALYZING...'
                            : 'ANALYZE VOICE',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}