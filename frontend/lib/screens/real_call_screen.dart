import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/voip_analysis_service.dart';
import '../services/call_service.dart';

class RealCallScreen extends StatefulWidget {
  final String clientId;
  final String role;

  const RealCallScreen({
    super.key,
    required this.clientId,
    required this.role,
  });

  @override
  State<RealCallScreen> createState() => _RealCallScreenState();
}

class _RealCallScreenState extends State<RealCallScreen> {
  CallService? _callService;
  VoIPAnalysisService? _analysisService;

  static const String serverUrl = 'ws://192.168.0.6:8000';
  static const String roomId = 'voice_shield_test_room';

  String _status = 'Initializing...';

  bool _signalingConnected = false;
  bool _peerReady = false;

  bool _inCall = false;
  bool _calling = false;
  bool _incomingCall = false;

  bool _muted = false;
  bool _speakerOn = true;

  bool _initializing = true;
  bool _reloading = false;

  int _initializationId = 0;

  String _riskLevel = 'WAITING';
  String _voiceResult = 'WAITING';
  String _recommendation =
      'VoiceShield analysis will start when the call connects.';

  double _aiProbability = 0.0;
  double _authenticity = 1.0;
  double _confidence = 0.0;

  int _riskScore = 0;

  bool _analysisConnected = false;
  bool _threatAlert = false;
  bool _analysisDevelopmentMode = true;

  bool get _isPersonA => widget.role.toUpperCase() == 'A';

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final int initId = ++_initializationId;

    if (mounted) {
      setState(() {
        _initializing = true;

        _signalingConnected = false;
        _peerReady = false;

        _inCall = false;
        _calling = false;
        _incomingCall = false;

        _muted = false;
        _speakerOn = true;

        _riskLevel = 'WAITING';
        _voiceResult = 'WAITING';

        _aiProbability = 0.0;
        _authenticity = 1.0;
        _confidence = 0.0;

        _riskScore = 0;

        _analysisConnected = false;
        _threatAlert = false;
        _analysisDevelopmentMode = true;

        _status = 'Connecting to VoiceShield server...';
      });
    }

    try {
      final service = CallService(
        clientId: widget.clientId,
        serverUrl: serverUrl,
      );

      _callService = service;

      service.onConnectionStateChanged = (state) {
        if (!mounted || initId != _initializationId) {
          return;
        }

        setState(() {
          _status = state;

          if (state == 'Signaling connected') {
            _signalingConnected = true;
          }

          if (state == 'Signaling disconnected') {
            _signalingConnected = false;
            _peerReady = false;
          }
        });
      };

      service.onRemoteDescription = (description) {
        if (!mounted || initId != _initializationId) {
          return;
        }

        if (!_isPersonA && description.type == 'offer') {
          setState(() {
            _incomingCall = true;
            _calling = false;
            _inCall = false;
            _status = 'Incoming call from Person A...';
          });

          Future.delayed(
            const Duration(milliseconds: 700),
            () {
              if (!mounted || initId != _initializationId) {
                return;
              }

              setState(() {
                _incomingCall = false;
                _inCall = true;
                _status = 'Call connected';
              });

              _startVoiceShieldAnalysis();
            },
          );
        }

        if (_isPersonA && description.type == 'answer') {
          setState(() {
            _calling = false;
            _incomingCall = false;
            _inCall = true;
            _status = 'Call connected';
          });

          _startVoiceShieldAnalysis();
        }
      };

      service.onCallEnded = () {
        if (!mounted || initId != _initializationId) {
          return;
        }

        _stopVoiceShieldAnalysis();

        setState(() {
          _incomingCall = false;
          _calling = false;
          _inCall = false;

          _status = 'Call ended';

          _riskLevel = 'WAITING';
          _voiceResult = 'WAITING';

          _aiProbability = 0.0;
          _authenticity = 1.0;
          _confidence = 0.0;

          _riskScore = 0;

          _analysisConnected = false;
          _threatAlert = false;
          _analysisDevelopmentMode = true;
        });
      };

      service.onError = (error) {
        if (!mounted || initId != _initializationId) {
          return;
        }

        setState(() {
          _status = error;
        });

        _showMessage(error);
      };

      await service.connectSignaling();

      if (!mounted || initId != _initializationId) {
        return;
      }

      await service.createPeerConnection();

      if (!mounted || initId != _initializationId) {
        return;
      }

      await service.initializeMicrophone();

      if (!mounted || initId != _initializationId) {
        return;
      }

      service.joinRoom(
        room: roomId,
      );

      if (!mounted || initId != _initializationId) {
        return;
      }

      setState(() {
        _initializing = false;
        _reloading = false;

        _status =
            'Waiting for Person ${_isPersonA ? 'B' : 'A'}...';
      });

      await Future.delayed(
        const Duration(milliseconds: 1000),
      );

      if (!mounted || initId != _initializationId) {
        return;
      }

      setState(() {
        _peerReady = service.peerId != null;
      });
    } catch (e) {
      if (!mounted || initId != _initializationId) {
        return;
      }

      setState(() {
        _initializing = false;
        _reloading = false;

        _signalingConnected = false;
        _peerReady = false;

        _inCall = false;
        _calling = false;
        _incomingCall = false;

        _status = 'Initialization failed';
      });

      _showMessage(
        'Call initialization failed: $e',
      );
    }
  }

  Future<void> _startVoiceShieldAnalysis() async {
    try {
      final callId =
          'call_${widget.clientId}_${DateTime.now().millisecondsSinceEpoch}';

      final analysisService = VoIPAnalysisService(
        serverUrl: serverUrl,
        callId: callId,
        clientId: widget.clientId,
      );

      _analysisService = analysisService;

      analysisService.onAnalysisUpdate = (data) {
        if (!mounted) {
          return;
        }

        _handleAnalysisUpdate(data);
      };

      analysisService.onConnectionStateChanged = (state) {
        if (!mounted) {
          return;
        }

        setState(() {
          _analysisConnected =
              state == 'VoiceShield analysis connected';
        });
      };

      analysisService.onError = (error) {
        if (!mounted) {
          return;
        }

        _showMessage(error);
      };

      setState(() {
        _riskLevel = 'ANALYZING';
        _voiceResult = 'ANALYZING';
        _analysisDevelopmentMode = true;
        _status = 'Call connected • VoiceShield analyzing...';
      });

      await analysisService.connect();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _analysisConnected = false;
      });

      _showMessage(
        'VoiceShield analysis connection failed: $e',
      );
    }
  }

  void _handleAnalysisUpdate(
    Map<String, dynamic> data,
  ) {
    final double aiProbability =
        _toDouble(data['ai_probability']);

    final double authenticity =
        _toDouble(data['authenticity']);

    final double confidence =
        _toDouble(data['confidence']);

    final int riskScore =
        _toInt(data['risk_score']);

    final String riskLevel =
        data['risk_level']?.toString() ?? 'UNKNOWN';

    final String voiceResult =
        data['voice_result']?.toString() ?? 'UNKNOWN';

    final String recommendation =
        data['recommendation']?.toString() ?? '';

    final bool threatTriggered =
        data['threat_alert_triggered'] == true;

    final bool developmentMode =
        data['is_development_mode'] == true;

    if (!mounted) {
      return;
    }

    setState(() {
      _aiProbability = aiProbability;
      _authenticity = authenticity;
      _confidence = confidence;

      _riskScore = riskScore;

      _riskLevel = riskLevel;
      _voiceResult = voiceResult;

      _recommendation = recommendation;

      _threatAlert = threatTriggered;

      _analysisDevelopmentMode = developmentMode;

      if (_inCall) {
        _status =
            'Call connected • VoiceShield monitoring';
      }
    });

    if (threatTriggered && riskLevel == 'HIGH') {
      _showThreatAlert();
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  void _showThreatAlert() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'HIGH RISK: Possible AI-generated or cloned voice detected.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopVoiceShieldAnalysis() async {
    try {
      await _analysisService?.disconnect();
    } catch (_) {}

    _analysisService = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _analysisConnected = false;
    });
  }

  Future<void> _reloadCall() async {
    if (_reloading) {
      return;
    }

    setState(() {
      _reloading = true;
      _initializing = true;

      _signalingConnected = false;
      _peerReady = false;

      _inCall = false;
      _calling = false;
      _incomingCall = false;

      _muted = false;
      _speakerOn = true;

      _riskLevel = 'WAITING';
      _voiceResult = 'WAITING';

      _aiProbability = 0.0;
      _authenticity = 1.0;
      _confidence = 0.0;

      _riskScore = 0;

      _analysisConnected = false;
      _threatAlert = false;
      _analysisDevelopmentMode = true;

      _status = 'Restarting call connection...';
    });

    _initializationId++;

    await _stopVoiceShieldAnalysis();

    final oldService = _callService;

    try {
      await oldService?.dispose();
    } catch (_) {}

    _callService = null;

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) {
      return;
    }

    await _initializeCall();
  }

  Future<void> _callPersonB() async {
    final service = _callService;

    if (service == null) {
      _showMessage(
        'Call service is not ready.',
      );
      return;
    }

    if (service.peerConnection == null) {
      _showMessage(
        'WebRTC connection is not ready.',
      );
      return;
    }

    if (service.peerId == null) {
      _showMessage(
        'Person B is not connected yet.',
      );
      return;
    }

    if (_calling || _inCall) {
      return;
    }

    try {
      setState(() {
        _calling = true;
        _status = 'Calling Person B...';
      });

      service.makeCall();

      if (!mounted) {
        return;
      }

      setState(() {
        _calling = true;
        _status = 'Calling Person B...';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _calling = false;
        _inCall = false;
        _status = 'Ready to call Person B';
      });

      _showMessage(
        'Could not make call: $e',
      );
    }
  }

  void _toggleMute() {
    final service = _callService;

    if (service == null) {
      return;
    }

    final stream = service.localStream;

    if (stream == null) {
      _showMessage(
        'Microphone stream is not ready.',
      );
      return;
    }

    final tracks = stream.getAudioTracks();

    if (tracks.isEmpty) {
      _showMessage(
        'No microphone track found.',
      );
      return;
    }

    for (final track in tracks) {
      track.enabled = _muted;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _muted = !_muted;
    });
  }

  Future<void> _toggleSpeaker() async {
    try {
      final newSpeakerState = !_speakerOn;

      await Helper.setSpeakerphoneOn(
        newSpeakerState,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _speakerOn = newSpeakerState;
      });
    } catch (e) {
      _showMessage(
        'Could not change speaker: $e',
      );
    }
  }

  Future<void> _hangUp() async {
    final service = _callService;

    if (service == null) {
      return;
    }

    try {
      await _stopVoiceShieldAnalysis();

      service.hangUp();

      if (!mounted) {
        return;
      }

      setState(() {
        _inCall = false;
        _calling = false;
        _incomingCall = false;

        _status = 'Call ended';

        _peerReady = false;

        _riskLevel = 'WAITING';
        _voiceResult = 'WAITING';

        _aiProbability = 0.0;
        _authenticity = 1.0;
        _confidence = 0.0;

        _riskScore = 0;

        _threatAlert = false;
      });
    } catch (e) {
      _showMessage(
        'Error ending call: $e',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _initializationId++;

    _analysisService?.disconnect();
    _callService?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080D1A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'VoiceShield Call',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload Call',
            onPressed: _reloading ? null : _reloadCall,
            icon: _reloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyanAccent,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    color: Colors.cyanAccent,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _initializing
            ? _buildLoading()
            : _buildMain(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield,
              size: 90,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 25),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: _reloading ? null : _reloadCall,
              icon: const Icon(
                Icons.refresh,
                color: Colors.cyanAccent,
              ),
              label: const Text(
                'RELOAD CONNECTION',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRoleCard(),
          const SizedBox(height: 20),
          _buildConnectionCard(),
          const SizedBox(height: 25),
          if (_inCall || _analysisConnected)
            _buildVoiceShieldScore(),
          if (_inCall || _analysisConnected)
            const SizedBox(height: 25),
          _buildCallCircle(),
          const SizedBox(height: 25),
          _buildStatus(),
          const SizedBox(height: 30),
          if (_incomingCall) _buildIncomingCall(),
          if (_isPersonA &&
              !_inCall &&
              !_calling &&
              !_incomingCall)
            _buildCallButton(),
          if (_isPersonA &&
              _calling &&
              !_inCall)
            _buildCallingCard(),
          if (!_isPersonA &&
              !_inCall &&
              !_incomingCall)
            _buildWaitingCard(),
          const SizedBox(height: 25),
          if (_inCall) _buildControls(),
          const SizedBox(height: 30),
          _buildProtectionCard(),
          const SizedBox(height: 30),
          _buildReloadButton(),
          const SizedBox(height: 25),
          Text(
            'Room: $roomId',
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Server: $serverUrl',
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVoiceShieldScore() {
    final bool highRisk =
        _riskLevel.toUpperCase() == 'HIGH';

    final bool mediumRisk =
        _riskLevel.toUpperCase() == 'MEDIUM';

    Color scoreColor;

    if (highRisk) {
      scoreColor = Colors.redAccent;
    } else if (mediumRisk) {
      scoreColor = Colors.orangeAccent;
    } else {
      scoreColor = Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highRisk
            ? const Color(0xFF291015)
            : const Color(0xFF101A2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highRisk
              ? Colors.redAccent
              : scoreColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                highRisk
                    ? Icons.warning_amber_rounded
                    : Icons.shield,
                color: scoreColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'VoiceShield Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _analysisConnected
                      ? Colors.greenAccent.withValues(alpha: 0.12)
                      : Colors.orangeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _analysisConnected
                      ? 'LIVE'
                      : 'CONNECTING',
                  style: TextStyle(
                    color: _analysisConnected
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: 145,
            height: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scoreColor,
                width: 5,
              ),
              color: scoreColor.withValues(alpha: 0.08),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_riskScore',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'RISK SCORE',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _riskLevel.toUpperCase(),
            style: TextStyle(
              color: scoreColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _voiceResult.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _analysisMetric(
                  title: 'AI VOICE',
                  value:
                      '${(_aiProbability * 100).toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analysisMetric(
                  title: 'AUTHENTIC',
                  value:
                      '${(_authenticity * 100).toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analysisMetric(
                  title: 'CONFIDENCE',
                  value:
                      '${(_confidence * 100).toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_recommendation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    highRisk
                        ? Icons.warning
                        : Icons.info_outline,
                    color: scoreColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _recommendation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_analysisDevelopmentMode)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Development mode — waiting for real model inference.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _analysisMetric({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isPersonA
                ? Icons.person
                : Icons.person_outline,
            size: 60,
            color: Colors.cyanAccent,
          ),
          const SizedBox(height: 15),
          Text(
            _isPersonA
                ? 'PERSON A'
                : 'PERSON B',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Client ID: ${widget.clientId}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    final service = _callService;

    final peerConnected =
        service?.peerId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _signalingConnected
                    ? Icons.check_circle
                    : Icons.error,
                color: _signalingConnected
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _signalingConnected
                      ? 'Signaling connected'
                      : 'Signaling disconnected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                peerConnected
                    ? Icons.person
                    : Icons.person_off,
                color: peerConnected
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  peerConnected
                      ? 'Person ${_isPersonA ? 'B' : 'A'} connected'
                      : 'Waiting for Person ${_isPersonA ? 'B' : 'A'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _analysisConnected
                    ? Icons.analytics
                    : Icons.analytics_outlined,
                color: _analysisConnected
                    ? Colors.cyanAccent
                    : Colors.white38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _analysisConnected
                      ? 'AI analysis connected'
                      : 'AI analysis waiting',
                  style: TextStyle(
                    color: _analysisConnected
                        ? Colors.cyanAccent
                        : Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallCircle() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _inCall
            ? Colors.green.withValues(alpha: 0.15)
            : _incomingCall
                ? Colors.orange.withValues(alpha: 0.15)
                : _calling
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.cyanAccent.withValues(alpha: 0.10),
        border: Border.all(
          color: _inCall
              ? Colors.greenAccent
              : _incomingCall
                  ? Colors.orangeAccent
                  : _calling
                      ? Colors.blueAccent
                      : Colors.cyanAccent,
          width: 2,
        ),
      ),
      child: Icon(
        _inCall
            ? Icons.phone_in_talk
            : _incomingCall
                ? Icons.phone_callback
                : _calling
                    ? Icons.phone_forwarded
                    : Icons.phone,
        size: 70,
        color: _inCall
            ? Colors.greenAccent
            : _incomingCall
                ? Colors.orangeAccent
                : _calling
                    ? Colors.blueAccent
                    : Colors.cyanAccent,
      ),
    );
  }

  Widget _buildStatus() {
    String text;
    Color color;

    if (_incomingCall) {
      text = 'INCOMING CALL';
      color = Colors.orangeAccent;
    } else if (_inCall) {
      text = 'CALL IN PROGRESS';
      color = Colors.greenAccent;
    } else if (_calling) {
      text = 'CALLING PERSON B...';
      color = Colors.blueAccent;
    } else if (_isPersonA) {
      text = 'Ready to call Person B';
      color = Colors.white;
    } else {
      text = 'Waiting for Person A';
      color = Colors.white;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildIncomingCall() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF241A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orangeAccent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.phone_callback,
            color: Colors.orangeAccent,
            size: 50,
          ),
          const SizedBox(height: 12),
          const Text(
            'PERSON A IS CALLING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'VoiceShield is automatically connecting the call...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          const CircularProgressIndicator(
            color: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton() {
    final enabled =
        _callService?.peerId != null &&
        !_calling;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: enabled
            ? _callPersonB
            : null,
        icon: const Icon(
          Icons.phone,
          color: Colors.black,
        ),
        label: const Text(
          'CALL PERSON B',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          disabledBackgroundColor:
              Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildCallingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.5),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.phone_forwarded,
            color: Colors.blueAccent,
            size: 40,
          ),
          SizedBox(height: 12),
          Text(
            'Calling Person B...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Waiting for Person B to receive the call.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.cyanAccent,
            size: 40,
          ),
          SizedBox(height: 12),
          Text(
            'Waiting for Person A...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'VoiceShield will notify you when Person A calls.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _muted
              ? Icons.mic_off
              : Icons.mic,
          label: _muted
              ? 'Unmute'
              : 'Mute',
          onPressed: _toggleMute,
        ),
        _controlButton(
          icon: _speakerOn
              ? Icons.volume_up
              : Icons.volume_off,
          label: _speakerOn
              ? 'Speaker'
              : 'Earpiece',
          onPressed: _toggleSpeaker,
        ),
        _controlButton(
          icon: Icons.call_end,
          label: 'End',
          color: Colors.redAccent,
          onPressed: _hangUp,
        ),
      ],
    );
  }

  Widget _buildProtectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _analysisConnected
              ? Colors.cyanAccent.withValues(alpha: 0.35)
              : Colors.greenAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield,
                color: _analysisConnected
                    ? Colors.cyanAccent
                    : Colors.greenAccent,
              ),
              const SizedBox(width: 10),
              const Text(
                'VoiceShield Protection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _analysisConnected
                ? 'Live audio analysis is connected. '
                  'VoiceShield is continuously evaluating '
                  'the call for voice-cloning risk.'
                : 'The call connection is protected by '
                  'the VoiceShield real-time analysis pipeline.',
            style: const TextStyle(
              color: Colors.white60,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _analysisConnected
                      ? Colors.cyanAccent
                      : Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _analysisConnected
                    ? 'Live AI monitoring active'
                    : 'Audio monitoring ready',
                style: TextStyle(
                  color: _analysisConnected
                      ? Colors.cyanAccent
                      : Colors.greenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _reloading
            ? null
            : _reloadCall,
        icon: _reloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.cyanAccent,
                ),
              )
            : const Icon(
                Icons.refresh,
                color: Colors.cyanAccent,
              ),
        label: Text(
          _reloading
              ? 'RESTARTING...'
              : 'RELOAD CALL',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Colors.cyanAccent,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.cyanAccent,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}