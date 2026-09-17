import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final Uint8List audioBytes;
  final String filename;

  const AnalysisScreen({
    super.key,
    required this.audioBytes,
    required this.filename,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();

  int _currentStageIndex = 0;
  String? _error;

  final List<String> _stages = [
    'Uploading audio package to FastAPI engine...',
    'Preprocessing audio waveform & normalizing rate...',
    'Preparing audio for AI detection...',
    'Checking audio quality...',
    'Completing AI voice analysis...',
  ];

  @override
  void initState() {
    super.initState();
    _executePipeline();
  }

  Future<void> _executePipeline() async {
    try {
      if (!mounted) return;
      setState(() => _currentStageIndex = 0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() => _currentStageIndex = 1);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() => _currentStageIndex = 2);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() => _currentStageIndex = 3);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() => _currentStageIndex = 4);

      final result = await _apiService.analyzeAudioBytes(
        bytes: widget.audioBytes,
        filename: widget.filename,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Shield Analysis'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.dangerRed,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Analysis Failed',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.dangerRed,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BACK'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cardSurface,
                    border: Border.all(
                      color: AppTheme.cyanAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyanAccent.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: AppTheme.cyanAccent,
                      strokeWidth: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  'Analyzing Audio',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  widget.filename,
                  style: const TextStyle(
                    color: AppTheme.cyanAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.cardBorder,
                    ),
                  ),
                  child: Column(
                    children: List.generate(
                      _stages.length,
                      (index) {
                        final isDone = index < _currentStageIndex;
                        final isCurrent = index == _currentStageIndex;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isDone
                                    ? Icons.check_circle
                                    : isCurrent
                                        ? Icons.sync
                                        : Icons.radio_button_unchecked,
                                color: isDone
                                    ? AppTheme.safeGreen
                                    : isCurrent
                                        ? AppTheme.cyanAccent
                                        : AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _stages[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isDone
                                        ? AppTheme.safeGreen
                                        : isCurrent
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.psychology,
                      color: AppTheme.cyanAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI Voice Detection Active',
                      style: TextStyle(
                        color: AppTheme.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                const Text(
                  'Running real AI voice analysis and speech-to-text processing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}