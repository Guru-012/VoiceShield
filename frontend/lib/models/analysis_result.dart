class AnalysisResult {
  final String analysisId;
  final String timestamp;
  final String filename;
  final String voiceResult;
  final String displayTitle;
  final double aiProbability;
  final double voiceConfidence;
  final String transcript;
  final double contextScore;
  final int riskScore;
  final String riskLevel;
  final List<String> indicators;
  final String recommendation;
  final bool isDevelopmentMode;
  final String demoDataNotice;
  final String disclaimer;

  AnalysisResult({
    required this.analysisId,
    required this.timestamp,
    required this.filename,
    required this.voiceResult,
    required this.displayTitle,
    required this.aiProbability,
    required this.voiceConfidence,
    required this.transcript,
    required this.contextScore,
    required this.riskScore,
    required this.riskLevel,
    required this.indicators,
    required this.recommendation,
    required this.isDevelopmentMode,
    required this.demoDataNotice,
    required this.disclaimer,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      analysisId: json['analysis_id'] ?? 'unknown',
      timestamp: json['timestamp'] ?? '',
      filename: json['filename'] ?? 'uploaded_audio.wav',
      voiceResult: json['voice_result'] ?? 'MODEL_NOT_CONNECTED',
      displayTitle: json['display_title'] ?? 'DEVELOPMENT MODE: AI Model Not Connected',
      aiProbability: (json['ai_probability'] as num?)?.toDouble() ?? 0.0,
      voiceConfidence: (json['voice_confidence'] as num?)?.toDouble() ?? 0.0,
      transcript: json['transcript'] ?? 'Speech-to-text model not connected in development mode.',
      contextScore: (json['context_score'] as num?)?.toDouble() ?? 0.0,
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: json['risk_level'] ?? 'DEV_MODE',
      indicators: (json['indicators'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendation: json['recommendation'] ?? '',
      isDevelopmentMode: json['is_development_mode'] ?? true,
      demoDataNotice: json['demo_data_notice'] ??
          'DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction.',
      disclaimer: json['disclaimer'] ?? 'DEVELOPMENT MODE',
    );
  }
}
