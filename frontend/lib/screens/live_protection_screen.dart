import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import '../services/realtime_voice_service.dart';

class LiveProtectionScreen extends StatefulWidget {
  const LiveProtectionScreen({super.key});

  @override
  State<LiveProtectionScreen> createState() => _LiveProtectionScreenState();
}

class _LiveProtectionScreenState extends State<LiveProtectionScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final RealtimeVoiceService _realtimeService = RealtimeVoiceService();

  // Emergency alert sound player
  final AudioPlayer _alertPlayer = AudioPlayer();

  bool _isInitializing = false;
  bool _isProtected = false;
  bool _isMicOn = false;

  // Prevent the alarm from playing repeatedly for the same
  // HIGH-risk detection stream.
  bool _alertAlreadyPlayed = false;

  String? _errorMessage;

  int _seconds = 0;
  Timer? _timer;

  StreamSubscription<Uint8List>? _audioSubscription;

  RealtimeDetectionData? _latestData;

  @override
  void dispose() {
    _timer?.cancel();
    _audioSubscription?.cancel();
    _recorder.dispose();
    _realtimeService.dispose();
    _stopAlertSound();
    _alertPlayer.dispose();

    super.dispose();
  }

  // ============================================================
  // START LIVE PROTECTION
  // ============================================================

  Future<void> _startLiveProtection() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _latestData = null;
      _isMicOn = false;
      _alertAlreadyPlayed = false;
    });

    try {
      // --------------------------------------------------------
      // 1. CREATE BACKEND SESSION
      // --------------------------------------------------------

      final sessionId = await _realtimeService.createSession();

      if (sessionId == null) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Failed to initialize real-time session on backend API server.';
        });

        return;
      }

      // --------------------------------------------------------
      // 2. DETECTION CALLBACK
      // --------------------------------------------------------

      _realtimeService.onDetectionResultReceived = (data) {
        if (!mounted) return;

        setState(() {
          _latestData = data;
        });

        // Check for HIGH risk after receiving detection result.
        _handleRiskAlert(data);
      };

      // --------------------------------------------------------
      // 3. ERROR CALLBACK
      // --------------------------------------------------------

      _realtimeService.onErrorOccurred = (err) {
        if (!mounted) return;

        setState(() {
          _errorMessage = err;
        });
      };

      // --------------------------------------------------------
      // 4. SESSION STATE CALLBACK
      // --------------------------------------------------------

      _realtimeService.onSessionStateChanged = (isActive) {
        if (!mounted) return;

        setState(() {
          _isProtected = isActive;

          if (!isActive) {
            _isMicOn = false;
          }
        });
      };

      // --------------------------------------------------------
      // 5. CONNECT WEBSOCKET
      // --------------------------------------------------------

      final wsConnected =
          await _realtimeService.startStreamingSession(sessionId);

      if (!wsConnected) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Could not connect to WebSocket real-time stream endpoint.';
        });

        return;
      }

      // --------------------------------------------------------
      // 6. START PROTECTION SESSION
      //
      // IMPORTANT:
      // Microphone is NOT started automatically.
      // User must press TURN ON MIC.
      // --------------------------------------------------------

      _seconds = 0;

      _timer?.cancel();

      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (mounted && _isProtected) {
            setState(() {
              _seconds++;
            });
          }
        },
      );

      setState(() {
        _isInitializing = false;
        _isProtected = true;
        _isMicOn = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isProtected = false;
          _isMicOn = false;

          _errorMessage = 'Initialization error: $e';
        });
      }
    }
  }

  // ============================================================
  // HIGH RISK ALERT
  // ============================================================

  Future<void> _handleRiskAlert(
    RealtimeDetectionData data,
  ) async {
    final isHighRisk = data.riskLevel.toUpperCase() == 'HIGH' ||
        data.threatAlertTriggered ||
        data.aiProbability >= 0.5;

    if (isHighRisk) {
      // Play only once until the risk returns to normal.
      if (!_alertAlreadyPlayed) {
        _alertAlreadyPlayed = true;

        await _playAlertSound();
      }
    } else {
      // Allow a future HIGH-risk event to trigger the alarm again.
      _alertAlreadyPlayed = false;

      // Stop any currently playing alert.
      await _stopAlertSound();
    }
  }

  // ============================================================
  // PLAY LOUD ALERT
  // ============================================================

  Future<void> _playAlertSound() async {
    try {
      await _alertPlayer.stop();

      await _alertPlayer.setReleaseMode(
        ReleaseMode.loop,
      );

      // Maximum player volume.
      await _alertPlayer.setVolume(1.0);

      await _alertPlayer.play(
        AssetSource('audio/high_risk_alert.mp3'),
      );
    } catch (e) {
      debugPrint(
        'Could not play HIGH-risk alert sound: $e',
      );
    }
  }

  // ============================================================
  // STOP ALERT
  // ============================================================

  Future<void> _stopAlertSound() async {
    try {
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(
        ReleaseMode.release,
      );
    } catch (_) {}
  }

  // ============================================================
  // TURN MICROPHONE ON
  // ============================================================

  Future<void> _turnMicOn() async {
    if (!_isProtected || _isMicOn) {
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
      });

      // --------------------------------------------------------
      // CHECK MICROPHONE PERMISSION
      // --------------------------------------------------------

      final hasPermission = await _recorder.hasPermission();

      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Microphone permission denied. Please allow microphone access.';
          });
        }

        return;
      }

      // --------------------------------------------------------
      // START PCM AUDIO STREAM
      // --------------------------------------------------------

      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // --------------------------------------------------------
      // SEND AUDIO ONLY WHILE MIC IS ON
      // --------------------------------------------------------

      _audioSubscription = audioStream.listen(
        (Uint8List chunkBytes) {
          if (_isMicOn && _isProtected) {
            _realtimeService.sendAudioChunk(
              chunkBytes,
            );
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isMicOn = false;
              _errorMessage =
                  'Microphone streaming error: $err';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isMicOn = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMicOn = false;
          _errorMessage =
              'Could not start microphone: $e';
        });
      }
    }
  }

  // ============================================================
  // TURN MICROPHONE OFF
  // ============================================================

  Future<void> _turnMicOff() async {
    // Stop sending audio immediately.
    if (mounted) {
      setState(() {
        _isMicOn = false;
      });
    }

    // Cancel audio stream subscription.
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // Stop microphone recorder.
    try {
      await _recorder.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isMicOn = false;
      });
    }
  }

  // ============================================================
  // TOGGLE MICROPHONE
  // ============================================================

  Future<void> _toggleMicrophone() async {
    if (!_isProtected) {
      return;
    }

    if (_isMicOn) {
      await _turnMicOff();
    } else {
      await _turnMicOn();
    }
  }

  // ============================================================
  // STOP LIVE PROTECTION
  // ============================================================

  Future<void> _stopLiveProtection() async {
    _timer?.cancel();
    _timer = null;

    // Stop microphone first.
    await _turnMicOff();

    // Stop emergency alert.
    await _stopAlertSound();

    _alertAlreadyPlayed = false;

    // Close backend session.
    await _realtimeService.stopSession();

    if (mounted) {
      setState(() {
        _isProtected = false;
        _isMicOn = false;
        _isInitializing = false;
        _latestData = null;
      });
    }
  }

  // ============================================================
  // FORMAT TIMER
  // ============================================================

  String _formatDuration() {
    final mins =
        (_seconds ~/ 60).toString().padLeft(2, '0');

    final secs =
        (_seconds % 60).toString().padLeft(2, '0');

    return '$mins:$secs';
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final hasThreatAlert = _latestData != null &&
        (_latestData!.threatAlertTriggered ||
            _latestData!.riskLevel.toUpperCase() == 'HIGH' ||
            _latestData!.aiProbability >= 0.5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Protection'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _isProtected
                  ? AppTheme.safeGreen
                      .withValues(alpha: 0.2)
                  : AppTheme.textSecondary
                      .withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: _isProtected
                    ? AppTheme.safeGreen
                    : AppTheme.textSecondary,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isProtected
                      ? Icons.sensors
                      : Icons.sensors_off,
                  size: 14,
                  color: _isProtected
                      ? AppTheme.safeGreen
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _isProtected
                      ? 'WS STREAMING'
                      : 'IDLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isProtected
                        ? AppTheme.safeGreen
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [

            // ==================================================
            // STATUS HEADER
            // ==================================================

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProtected
                            ? (hasThreatAlert
                                ? AppTheme.dangerRed
                                    .withValues(
                                        alpha: 0.2)
                                : AppTheme.safeGreen
                                    .withValues(
                                        alpha: 0.15))
                            : AppTheme.cardSurface,
                        border: Border.all(
                          color: _isProtected
                              ? (hasThreatAlert
                                  ? AppTheme.dangerRed
                                  : AppTheme.safeGreen)
                              : AppTheme.cardBorder,
                          width: 3,
                        ),
                        boxShadow: _isProtected
                            ? [
                                BoxShadow(
                                  color: (hasThreatAlert
                                          ? AppTheme
                                              .dangerRed
                                          : AppTheme
                                              .safeGreen)
                                      .withValues(
                                          alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        hasThreatAlert
                            ? Icons.warning_amber
                            : (_isProtected
                                ? Icons.shield
                                : Icons
                                    .shield_outlined),
                        size: 56,
                        color: _isProtected
                            ? (hasThreatAlert
                                ? AppTheme.dangerRed
                                : AppTheme.safeGreen)
                            : AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _isInitializing
                          ? 'Initializing Session...'
                          : (_isProtected
                              ? 'LIVE PROTECTION ACTIVE'
                              : 'Protection Stopped'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color: _isProtected
                            ? (hasThreatAlert
                                ? AppTheme.dangerRed
                                : AppTheme.safeGreen)
                            : AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _isProtected
                          ? 'Session: ${_realtimeService.activeSessionId ?? "rs_active"}'
                          : 'Tap start button below to launch real-time protection',
                      style: const TextStyle(
                        fontSize: 12,
                        color:
                            AppTheme.textSecondary,
                      ),
                    ),

                    if (_isProtected) ...[
                      const SizedBox(height: 12),

                      Text(
                        _formatDuration(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ==================================================
            // MICROPHONE CONTROL
            // ==================================================

            if (_isProtected) ...[
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        _isMicOn
                            ? Icons.mic
                            : Icons.mic_off,
                        size: 42,
                        color: _isMicOn
                            ? AppTheme.dangerRed
                            : AppTheme.textSecondary,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _isMicOn
                            ? 'MICROPHONE ON'
                            : 'MICROPHONE OFF',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color: _isMicOn
                              ? AppTheme.dangerRed
                              : AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _isMicOn
                            ? 'Voice audio is being captured and analyzed'
                            : 'Microphone is off. No voice audio is being sent.',
                        textAlign:
                            TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color:
                              AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _toggleMicrophone,
                          icon: Icon(
                            _isMicOn
                                ? Icons.mic_off
                                : Icons.mic,
                          ),
                          label: Text(
                            _isMicOn
                                ? 'TURN OFF MIC'
                                : 'TURN ON MIC',
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                _isMicOn
                                    ? AppTheme
                                        .dangerRed
                                    : AppTheme
                                        .cyanAccent,
                            foregroundColor:
                                _isMicOn
                                    ? Colors.white
                                    : Colors.black,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ==================================================
            // ERROR
            // ==================================================

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),

              Container(
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed
                      .withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        AppTheme.dangerRed,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color:
                          AppTheme.dangerRed,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style:
                            const TextStyle(
                          color:
                              AppTheme.dangerRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // HIGH RISK ALERT
            // ==================================================

            const SizedBox(height: 20),

            if (hasThreatAlert) ...[
              Container(
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed
                      .withValues(alpha: 0.25),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        AppTheme.dangerRed,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning,
                          color:
                              AppTheme.dangerRed,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '🚨 HIGH RISK THREAT ALERT',
                            style: TextStyle(
                              color:
                                  AppTheme.dangerRed,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volume_up,
                          color:
                              AppTheme.dangerRed,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'LOUD ALERT PLAYING',
                          style: TextStyle(
                            color:
                                AppTheme.dangerRed,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _latestData
                              ?.displayTitle ??
                          'AI Voice Cloning / Impersonation Anomaly Detected!',
                      style: const TextStyle(
                        color:
                            AppTheme.textPrimary,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign:
                          TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Do not share passwords, OTPs, or transfer money based on this incoming audio stream.',
                      style: TextStyle(
                        color:
                            AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign:
                          TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],

            // ==================================================
            // METRICS
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title:
                        'AI Probability',
                    value: _latestData != null
                        ? '${(_latestData!.aiProbability * 100).toInt()}%'
                        : '--',
                    color: hasThreatAlert
                        ? AppTheme.dangerRed
                        : AppTheme.cyanAccent,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Authenticity',
                    value: _latestData != null
                        ? '${(_latestData!.authenticity * 100).toInt()}%'
                        : '--',
                    color:
                        AppTheme.safeGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Confidence',
                    value: _latestData != null
                        ? '${(_latestData!.confidence * 100).toInt()}%'
                        : '--',
                    color:
                        AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Risk Level',
                    value:
                        _latestData?.riskLevel ??
                            '--',
                    color: hasThreatAlert
                        ? AppTheme.dangerRed
                        : (_latestData?.riskLevel
                                    .toUpperCase() ==
                                'MEDIUM'
                            ? AppTheme
                                .warningAmber
                            : AppTheme
                                .safeGreen),
                  ),
                ),
              ],
            ),

            // ==================================================
            // TRANSCRIPT
            // ==================================================

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons
                              .record_voice_over,
                          color:
                              AppTheme.cyanAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Live Speech-to-Text Transcript',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                              12),
                      decoration:
                          BoxDecoration(
                        color:
                            AppTheme.darkBackground,
                        borderRadius:
                            BorderRadius.circular(
                                10),
                      ),
                      child: Text(
                        (_latestData != null &&
                                _latestData!
                                    .transcript
                                    .isNotEmpty)
                            ? _latestData!
                                .transcript
                            : (_isMicOn
                                ? 'Listening for speech...'
                                : (_isProtected
                                    ? 'Microphone is OFF. Turn it on to start voice analysis.'
                                    : 'No transcript recorded yet.')),
                        style: TextStyle(
                          fontSize: 13,
                          color: (_latestData !=
                                      null &&
                                  _latestData!
                                      .transcript
                                      .isNotEmpty)
                              ? AppTheme
                                  .textPrimary
                              : AppTheme
                                  .textSecondary,
                          fontStyle: (_latestData !=
                                      null &&
                                  _latestData!
                                      .transcript
                                      .isNotEmpty)
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // SUSPICIOUS CONTEXT
            // ==================================================

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color:
                              AppTheme.warningAmber,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Suspicious Context Indicators',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_latestData == null ||
                        _latestData!
                            .indicators
                            .isEmpty)
                      const Text(
                        'No suspicious manipulation keywords detected in stream.',
                        style: TextStyle(
                          color:
                              AppTheme.safeGreen,
                          fontSize: 13,
                        ),
                      )
                    else
                      Column(
                        children:
                            _latestData!
                                .indicators
                                .map(
                          (indicator) {
                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                bottom: 8.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    color: AppTheme
                                        .warningAmber,
                                    size: 16,
                                  ),
                                  const SizedBox(
                                      width: 8),
                                  Expanded(
                                    child: Text(
                                      indicator,
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            13,
                                        color: AppTheme
                                            .textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // STOP / START
            // ==================================================

            const SizedBox(height: 28),

            if (_isProtected)
              ElevatedButton.icon(
                onPressed:
                    _stopLiveProtection,
                icon: const Icon(
                    Icons.stop),
                label: const Text(
                    'STOP PROTECTION'),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.dangerRed,
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 18,
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed:
                    _isInitializing
                        ? null
                        : _startLiveProtection,
                icon: const Icon(
                    Icons.security),
                label: Text(
                  _isInitializing
                      ? 'CONNECTING...'
                      : 'START LIVE PROTECTION',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.cyanAccent,
                  foregroundColor:
                      Colors.black,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // METRIC CARD
  // ============================================================

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            AppTheme.cardSurface,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}