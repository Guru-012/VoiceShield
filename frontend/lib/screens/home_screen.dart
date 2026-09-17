import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

import 'upload_screen.dart';
import 'history_screen.dart';
import 'safety_tips_screen.dart';
import 'settings_screen.dart';
import '../record_voice_screen.dart';
import 'live_protection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isBackendConnected = false;
  bool _checkingHealth = true;

  List<Map<String, dynamic>> _recentHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchStatusAndHistory();
  }

  // ================================================================
  // FETCH BACKEND STATUS + RECENT HISTORY
  // ================================================================

  Future<void> _fetchStatusAndHistory() async {
    if (!mounted) return;

    setState(() {
      _checkingHealth = true;
    });

    try {
      final connected = await _apiService.checkHealth();
      final history = await _apiService.getHistory();

      if (!mounted) return;

      setState(() {
        _isBackendConnected = connected;

        // Show the two latest analysis records
        _recentHistory = history.take(2).toList();

        _checkingHealth = false;
      });
    } catch (e) {
      debugPrint('Home history refresh error: $e');

      if (!mounted) return;

      setState(() {
        _checkingHealth = false;
      });
    }
  }

  // ================================================================
  // OPEN UPLOAD SCREEN + REFRESH WHEN USER RETURNS
  // ================================================================

  Future<void> _openUploadScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadScreen(),
      ),
    );

    // Refresh history after analysis
    await _fetchStatusAndHistory();
  }

  // ================================================================
  // OPEN RECORD SCREEN + REFRESH WHEN USER RETURNS
  // ================================================================

  Future<void> _openRecordScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordVoiceScreen(),
      ),
    );

    // Refresh history after recording/analysis
    await _fetchStatusAndHistory();
  }

  // ================================================================
  // OPEN HISTORY
  // ================================================================

  Future<void> _openHistoryScreen() async {
    await _fetchStatusAndHistory();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryScreen(),
      ),
    );

    // Refresh when returning from History
    await _fetchStatusAndHistory();
  }

  // ================================================================
  // OPEN LIVE PROTECTION
  // ================================================================

  Future<void> _openLiveProtection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveProtectionScreen(),
      ),
    );

    // Refresh after returning
    await _fetchStatusAndHistory();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,

        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              color: AppTheme.cyanAccent,
            ),
            SizedBox(width: 8),
            Text('VoiceShield'),
          ],
        ),

        actions: [
          // HISTORY
          IconButton(
            icon: const Icon(
              Icons.history,
              color: AppTheme.cyanAccent,
            ),
            onPressed: _openHistoryScreen,
          ),

          // SETTINGS
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: AppTheme.cyanAccent,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),

      // ==============================================================
      // BODY
      // ==============================================================

      body: RefreshIndicator(
        onRefresh: _fetchStatusAndHistory,
        color: AppTheme.cyanAccent,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ======================================================
              // BACKEND STATUS
              // ======================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: _isBackendConnected
                            ? AppTheme.safeGreen.withValues(alpha: 0.15)
                            : AppTheme.dangerRed.withValues(alpha: 0.15),

                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(
                          color: _isBackendConnected
                              ? AppTheme.safeGreen
                              : AppTheme.dangerRed,
                        ),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Icon(
                            _isBackendConnected
                                ? Icons.check_circle
                                : Icons.error_outline,

                            size: 14,

                            color: _isBackendConnected
                                ? AppTheme.safeGreen
                                : AppTheme.dangerRed,
                          ),

                          const SizedBox(width: 6),

                          Flexible(
                            child: Text(
                              _checkingHealth
                                  ? 'Checking Core API...'
                                  : (_isBackendConnected
                                      ? 'FastAPI Engine Connected (DEV MODE)'
                                      : 'Backend Disconnected'),

                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,

                                color: _isBackendConnected
                                    ? AppTheme.safeGreen
                                    : AppTheme.dangerRed,
                              ),

                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: _fetchStatusAndHistory,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ======================================================
              // MAIN PROTECTION CARD
              // ======================================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),

                            decoration: BoxDecoration(
                              color: AppTheme.cyanAccent.withValues(
                                alpha: 0.1,
                              ),

                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: AppTheme.cyanAccent,
                              size: 32,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Protect yourself from AI voice scams',

                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontSize: 18,
                                      ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Scan incoming voice messages or call recordings for synthetic AI cloning.',

                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton.icon(
                          onPressed: _openUploadScreen,

                          icon: const Icon(
                            Icons.analytics_outlined,
                          ),

                          label: const Text(
                            'Analyze Voice File',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ======================================================
              // PHASE 3 LIVE PROTECTION
              // ======================================================

              Card(
                color: AppTheme.cardSurface,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),

                  side: BorderSide(
                    color: AppTheme.safeGreen.withValues(
                      alpha: 0.8,
                    ),

                    width: 1.5,
                  ),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(18),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // HEADER
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,

                        children: [
                          Container(
                            width: 54,
                            height: 54,

                            decoration: BoxDecoration(
                              color: AppTheme.safeGreen.withValues(
                                alpha: 0.15,
                              ),

                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.security,
                              color: AppTheme.safeGreen,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              'Phase 3 • Live Protection',

                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // DESCRIPTION
                      const Text(
                        'Real-time voice monitoring with WebSocket streaming, AI detection, and live threat alerts.',

                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // START LIVE BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,

                        child: ElevatedButton.icon(
                          onPressed: _openLiveProtection,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.safeGreen,
                            foregroundColor: Colors.black,
                            elevation: 0,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          icon: const Icon(
                            Icons.shield_outlined,
                            size: 20,
                          ),

                          label: const Text(
                            'START LIVE PROTECTION',

                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ======================================================
              // AUDIO SOURCE
              // ======================================================

              Text(
                'Audio Source',

                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontSize: 16,
                    ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  // ====================================================
                  // UPLOAD AUDIO
                  // ====================================================

                  Expanded(
                    child: InkWell(
                      onTap: _openUploadScreen,

                      borderRadius: BorderRadius.circular(16),

                      child: Container(
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(
                            color: AppTheme.cyanAccent.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),

                        child: const Column(
                          children: [
                            Icon(
                              Icons.upload_file,
                              color: AppTheme.cyanAccent,
                              size: 36,
                            ),

                            SizedBox(height: 12),

                            Text(
                              'Upload Audio',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'WAV, MP3, M4A',

                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ====================================================
                  // RECORD VOICE
                  // ====================================================

                  Expanded(
                    child: InkWell(
                      onTap: _openRecordScreen,

                      borderRadius: BorderRadius.circular(16),

                      child: Container(
                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(
                            color: AppTheme.cardBorder,
                          ),
                        ),

                        child: const Column(
                          children: [
                            Icon(
                              Icons.mic,
                              color: AppTheme.dangerRed,
                              size: 36,
                            ),

                            SizedBox(height: 12),

                            Text(
                              'Record Voice',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'Live mic capture',

                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ======================================================
              // RECENT ANALYSIS
              // ======================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    'Recent Analysis',

                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontSize: 16,
                        ),
                  ),

                  TextButton(
                    onPressed: _openHistoryScreen,

                    child: const Text(
                      'View All',

                      style: TextStyle(
                        color: AppTheme.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ======================================================
              // NO HISTORY
              // ======================================================

              if (_recentHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Center(
                      child: Text(
                        'No voice analyses performed yet. Upload an audio file to test detection.',

                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium,

                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )

              // ======================================================
              // HISTORY RESULTS
              // ======================================================

              else
                Column(
                  children: _recentHistory.map((item) {
                    final riskLevel =
                        (item['risk_level'] ?? 'LOW')
                            .toString()
                            .toUpperCase();

                    final isHigh = riskLevel == 'HIGH';
                    final isMed = riskLevel == 'MEDIUM';

                    final color = isHigh
                        ? AppTheme.dangerRed
                        : (isMed
                            ? AppTheme.warningAmber
                            : AppTheme.safeGreen);

                    final filename =
                        (item['filename'] ??
                                item['file_name'] ??
                                'Audio Analysis')
                            .toString();

                    final riskScore =
                        item['risk_score'] ?? 0;

                    final voiceResult =
                        (item['voice_result'] ??
                                item['voice_detection'] ??
                                '')
                            .toString();

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: 8,
                      ),

                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),

                        leading: CircleAvatar(
                          backgroundColor:
                              color.withValues(alpha: 0.2),

                          child: Icon(
                            isHigh
                                ? Icons.warning_amber
                                : Icons.security,

                            color: color,
                          ),
                        ),

                        title: Text(
                          filename,

                          overflow:
                              TextOverflow.ellipsis,

                          maxLines: 1,
                        ),

                        subtitle: Text(
                          'Risk Score: $riskScore/100 • $riskLevel',

                          overflow:
                              TextOverflow.ellipsis,

                          maxLines: 1,
                        ),

                        trailing: Container(
                          constraints:
                              const BoxConstraints(
                            maxWidth: 90,
                          ),

                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),

                          decoration: BoxDecoration(
                            color:
                                color.withValues(
                              alpha: 0.2,
                            ),

                            borderRadius:
                                BorderRadius.circular(8),
                          ),

                          child: Text(
                            voiceResult.isEmpty
                                ? riskLevel
                                : voiceResult,

                            maxLines: 1,

                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              // ======================================================
              // SAFETY TIPS
              // ======================================================

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.shield,
                    color: AppTheme.cyanAccent,
                  ),

                  title: const Text(
                    'Voice Anti-Scam Tips',
                  ),

                  subtitle: const Text(
                    'Never transfer money or share OTP based on urgent voice calls alone.',
                  ),

                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.cyanAccent,
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const SafetyTipsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}