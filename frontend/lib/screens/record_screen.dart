import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;

  // ================================================================
  // START / STOP RECORDING
  // ================================================================

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _seconds = 0;
    });

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _seconds++;
        });
      },
    );
  }

  void _stopRecording() {
    _timer?.cancel();
    _timer = null;

    setState(() {
      _isRecording = false;
    });
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ================================================================
  // TIME FORMAT
  // ================================================================

  String _formatTime() {
    final minutes =
        (_seconds ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (_seconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ================================================================
  // BUILD
  // ================================================================

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

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // ==================================================
                // MICROPHONE ICON
                // ==================================================

                Container(
                  width: 120,
                  height: 120,

                  decoration: BoxDecoration(
                    color: AppTheme.cyanAccent.withValues(
                      alpha: 0.12,
                    ),

                    shape: BoxShape.circle,

                    border: Border.all(
                      color: AppTheme.cyanAccent.withValues(
                        alpha: 0.5,
                      ),
                      width: 2,
                    ),
                  ),

                  child: Icon(
                    _isRecording
                        ? Icons.mic
                        : Icons.mic_none,

                    size: 60,

                    color: _isRecording
                        ? AppTheme.dangerRed
                        : AppTheme.cyanAccent,
                  ),
                ),

                const SizedBox(height: 32),

                // ==================================================
                // TIMER
                // ==================================================

                Text(
                  _formatTime(),

                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // STATUS
                // ==================================================

                Text(
                  _isRecording
                      ? 'Recording your voice...'
                      : _seconds > 0
                          ? 'Recording completed'
                          : 'Tap the button to start',

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 36),

                // ==================================================
                // RECORD BUTTON
                // ==================================================

                SizedBox(
                  width: 300,
                  height: 54,

                  child: ElevatedButton.icon(
                    onPressed: _toggleRecording,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording
                          ? AppTheme.dangerRed
                          : AppTheme.cyanAccent,

                      foregroundColor: Colors.black,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),

                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),

                    icon: Icon(
                      _isRecording
                          ? Icons.stop
                          : Icons.mic,
                    ),

                    label: Text(
                      _isRecording
                          ? 'STOP RECORDING'
                          : 'START RECORDING',

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // RECORDING INFO
                // ==================================================

                if (_seconds > 0 && !_isRecording)
                  Container(
                    width: 300,

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,

                      borderRadius:
                          BorderRadius.circular(12),

                      border: Border.all(
                        color: AppTheme.cardBorder,
                      ),
                    ),

                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.safeGreen,
                          size: 20,
                        ),

                        SizedBox(width: 8),

                        Text(
                          'Recording ready',
                          style: TextStyle(
                            color: AppTheme.safeGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}