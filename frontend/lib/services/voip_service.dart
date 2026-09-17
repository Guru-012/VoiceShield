import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum VoIPCallState {
  idle,
  connectingSignaling,
  roomJoined,
  offering,
  answering,
  connected,
  ended,
  error
}

class VoIPService {
  final String serverHost; // e.g. "127.0.0.1:8000" or "192.168.1.100:8000"
  late String clientId;

  WebSocketChannel? _signalingChannel;
  WebSocketChannel? _audioStreamChannel;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  VoIPCallState _callState = VoIPCallState.idle;
  String? _currentRoomId;
  String? _targetClientId;
  String? _activeCallId;

  // Event Callbacks
  Function(VoIPCallState state)? onCallStateChanged;
  Function(MediaStream remoteStream)? onRemoteStreamReceived;
  Function(String errorMessage)? onErrorOccurred;
  Function(Map<String, dynamic> alertData)? onAIThreatAlertReceived;

  VoIPService({required this.serverHost, String? clientId}) {
    this.clientId = clientId ?? 'client_${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  VoIPCallState get callState => _callState;
  String? get activeCallId => _activeCallId;
  String? get currentRoomId => _currentRoomId;

  void _updateState(VoIPCallState newState) {
    _callState = newState;
    onCallStateChanged?.call(newState);
  }

  // ------------------------------------------------------------------------
  // 1. PERMISSION HANDLING
  // ------------------------------------------------------------------------
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      onErrorOccurred?.call('Microphone permission is required for VoIP calls.');
      return false;
    }
    return true;
  }

  // ------------------------------------------------------------------------
  // 2. WEBSOCKET SIGNALING CONNECTION
  // ------------------------------------------------------------------------
  Future<bool> connectSignaling() async {
    try {
      _updateState(VoIPCallState.connectingSignaling);
      final wsUrl = Uri.parse('ws://$serverHost/api/ws/voip/signal/$clientId');
      _signalingChannel = WebSocketChannel.connect(wsUrl);

      _signalingChannel!.stream.listen(
        (data) => _handleSignalingMessage(data),
        onError: (err) {
          _updateState(VoIPCallState.error);
          onErrorOccurred?.call('Signaling connection error: $err');
        },
        onDone: () {
          if (_callState != VoIPCallState.ended) {
            _updateState(VoIPCallState.ended);
          }
        },
      );

      return true;
    } catch (e) {
      _updateState(VoIPCallState.error);
      onErrorOccurred?.call('Failed to connect to signaling server: $e');
      return false;
    }
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _sendSignaling({
      'type': 'join_room',
      'room_id': roomId,
    });
  }

  // ------------------------------------------------------------------------
  // 3. WEBRTC PEER CONNECTION SETUP
  // ------------------------------------------------------------------------
  Future<void> _createPeerConnection(String targetId) async {
    _targetClientId = targetId;

    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    // Get local microphone audio stream
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle ICE candidates generated locally
    _peerConnection!.onIceCandidate = (candidate) {
      if (_targetClientId != null) {
        _sendSignaling({
          'type': 'ice_candidate',
          'target_id': _targetClientId,
          'candidate': candidate.toMap(),
        });
      }
    };

    // Handle remote track received from peer
    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStreamReceived?.call(_remoteStream!);
      }
    };

    // Connection state monitoring
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateState(VoIPCallState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _updateState(VoIPCallState.ended);
      }
    };
  }

  // ------------------------------------------------------------------------
  // 4. CALL INITIATION (CALLER)
  // ------------------------------------------------------------------------
  Future<void> startCall(String targetId, String roomId) async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) return;

      _activeCallId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _updateState(VoIPCallState.offering);

      await _createPeerConnection(targetId);

      final RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });

      await _peerConnection!.setLocalDescription(offer);

      _sendSignaling({
        'type': 'offer',
        'target_id': targetId,
        'room_id': roomId,
        'call_id': _activeCallId,
        'sdp': offer.sdp,
      });
    } catch (e) {
      _updateState(VoIPCallState.error);
      onErrorOccurred?.call('Failed to start call: $e');
    }
  }

  // ------------------------------------------------------------------------
  // 5. SIGNALING MESSAGE DISPATCHER
  // ------------------------------------------------------------------------
  void _handleSignalingMessage(dynamic data) async {
    try {
      final Map<String, dynamic> msg = jsonDecode(data);
      final type = msg['type'];
      final senderId = msg['sender_id'];

      if (type == 'room_joined') {
        _updateState(VoIPCallState.roomJoined);
      } else if (type == 'offer') {
        _activeCallId = msg['call_id'] ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
        _targetClientId = senderId;
        _updateState(VoIPCallState.answering);

        await _createPeerConnection(senderId);

        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(msg['sdp'], 'offer'),
        );

        final RTCSessionDescription answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 0,
        });

        await _peerConnection!.setLocalDescription(answer);

        _sendSignaling({
          'type': 'answer',
          'target_id': senderId,
          'call_id': _activeCallId,
          'sdp': answer.sdp,
        });
      } else if (type == 'answer') {
        if (_peerConnection != null) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(msg['sdp'], 'answer'),
          );
        }
      } else if (type == 'ice_candidate') {
        if (_peerConnection != null && msg['candidate'] != null) {
          final candMap = Map<String, dynamic>.from(msg['candidate']);
          await _peerConnection!.addCandidate(
            RTCIceCandidate(
              candMap['candidate'],
              candMap['sdpMid'],
              candMap['sdpMLineIndex'],
            ),
          );
        }
      } else if (type == 'hangup') {
        endCall();
      }
    } catch (e) {
      onErrorOccurred?.call('Signaling parsing error: $e');
    }
  }

  void _sendSignaling(Map<String, dynamic> msg) {
    if (_signalingChannel != null) {
      _signalingChannel!.sink.add(jsonEncode(msg));
    }
  }

  // ------------------------------------------------------------------------
  // 6. LIVE AI AUDIO STREAMING HOOK (PHASE 3 PREPARATION)
  // ------------------------------------------------------------------------
  Future<void> connectAudioStreamingWebSocket(String callId) async {
    try {
      final wsUrl = Uri.parse('ws://$serverHost/api/ws/voip/stream/$callId/$clientId');
      _audioStreamChannel = WebSocketChannel.connect(wsUrl);

      _audioStreamChannel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = jsonDecode(data);
            if (msg['type'] == 'ai_threat_update' && msg['data'] != null) {
              onAIThreatAlertReceived?.call(Map<String, dynamic>.from(msg['data']));
            }
          } catch (_) {}
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void streamAudioPCMChunk(Uint8List chunkBytes) {
    if (_audioStreamChannel != null) {
      _audioStreamChannel!.sink.add(chunkBytes);
    }
  }

  // ------------------------------------------------------------------------
  // 7. CLEANUP & HANGUP
  // ------------------------------------------------------------------------
  Future<void> endCall() async {
    if (_callState == VoIPCallState.ended || _callState == VoIPCallState.idle) return;

    if (_targetClientId != null) {
      _sendSignaling({
        'type': 'hangup',
        'target_id': _targetClientId,
      });
    }

    _updateState(VoIPCallState.ended);

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _audioStreamChannel?.sink.close();
    _audioStreamChannel = null;

    _targetClientId = null;
    _activeCallId = null;
  }

  void dispose() {
    endCall();
    _signalingChannel?.sink.close();
    _signalingChannel = null;
  }
}
