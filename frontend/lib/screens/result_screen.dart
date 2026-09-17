import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/analysis_result.dart';
import 'home_screen.dart';

class ResultScreen extends StatelessWidget {
  final AnalysisResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDevMode = result.isDevelopmentMode;
    final isHigh = result.riskLevel == 'HIGH';
    final isMed = result.riskLevel == 'MEDIUM';

    final riskColor = isDevMode
        ? AppTheme.cyanAccent
        : (isHigh
            ? AppTheme.dangerRed
            : (isMed ? AppTheme.warningAmber : AppTheme.safeGreen));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Analysis Report'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Requirement 1 & 6: Prominent DEVELOPMENT MODE Header Banner
            if (isDevMode)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.warningAmber, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.developer_mode, color: AppTheme.warningAmber, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'DEVELOPMENT MODE ACTIVE',
                          style: TextStyle(
                            color: AppTheme.warningAmber.withValues(alpha: 0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI voice detection model is not connected yet.',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

            // Main Result Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: riskColor, width: 1.5),
                      ),
                      child: Text(
                        isDevMode
                            ? 'DEVELOPMENT PIPELINE TEST'
                            : '${result.riskLevel} RISK • SCORE ${result.riskScore}/100',
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Requirement 2 & 3: User-facing status title
                    Text(
                      isDevMode
                         ? result.displayTitle
                         : (result.voiceResult == 'AI_VOICE_DETECTED'
                              ? 'AI-GENERATED / CLONED VOICE DETECTED'
                              : result.voiceResult == 'POSSIBLY_AI_GENERATED'
                                       ? 'POSSIBLY AI-GENERATED'
                                       : 'REAL HUMAN VOICE DETECTED'),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 20,
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'File: ${result.filename}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Requirement 5: Demo Data Layout Meters Notice
                    if (isDevMode) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'DEMO DATA — NOT A REAL MODEL PREDICTION',
                              style: TextStyle(
                                color: AppTheme.warningAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Inference pending Phase 3 PyTorch deepfake model integration.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMeterItem(
                          context,
                          label: 'AI Probability',
                          value: isDevMode ? 'N/A (Dev)' : '${(result.aiProbability * 100).toInt()}%',
                          color: isDevMode ? AppTheme.textSecondary : riskColor,
                        ),
                        _buildMeterItem(
                          context,
                          label: 'Authenticity',
                          value: isDevMode ? 'N/A (Dev)' : '${((1.0 - result.aiProbability) * 100).toInt()}%',
                          color: AppTheme.cyanAccent,
                        ),
                        _buildMeterItem(
                          context,
                          label: 'Confidence',
                          value: isDevMode ? 'N/A (Dev)' : '${(result.voiceConfidence * 100).toInt()}%',
                          color: AppTheme.textPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Requirement 4: Speech-to-Text Transcript Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: AppTheme.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Speech-to-Text Transcript',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        result.transcript,
                        style: TextStyle(
                          fontStyle: isDevMode ? FontStyle.italic : FontStyle.normal,
                          color: isDevMode ? AppTheme.warningAmber : AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Context Indicators Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flag_outlined, color: AppTheme.warningAmber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Suspicious Context Indicators',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (result.indicators.isEmpty)
                      const Text(
                        'No suspicious scam manipulation keywords detected.',
                        style: TextStyle(color: AppTheme.safeGreen, fontSize: 13),
                      )
                    else
                      Column(
                        children: result.indicators.map((ind) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  isDevMode ? Icons.info_outline : Icons.warning,
                                  color: isDevMode ? AppTheme.cyanAccent : AppTheme.warningAmber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ind,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDevMode ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recommendation Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gavel, color: AppTheme.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'System Status & Recommendation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.recommendation,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Analyze Another Voice Clip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
