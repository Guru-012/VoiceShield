import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:web_socket_channel/web_socket_channel.dart';

class CallService {
  // ============================================================
  // WEBRTC
  // ============================================================

  webrtc.RTCPeerConnection? peerConnection;
  webrtc.MediaStream? localStream;

  // ============================================================
  // SIGNALING
  // ============================================================

  WebSocketChannel? _socket;
  StreamSubscription? _socketSubscription;

  // ============================================================
  // CLIENT
  // ============================================================

  final String clientId;
  final String serverUrl;

  String? roomId;
  String? peerId;

  // ============================================================
  // CALLBACKS
  // ============================================================

  Function(webrtc.RTCSessionDescription)? onRemoteDescription;
  Function(webrtc.RTCIceCandidate)? onRemoteIceCandidate;

  Function()? onCallEnded;
  Function()? onIncomingCall;

  Function(String)? onError;
  Function(String)? onConnectionStateChanged;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _disposed = false;
  bool _remoteDescriptionSet = false;
  bool _makingCall = false;

  final List<webrtc.RTCIceCandidate> _pendingIceCandidates = [];

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  CallService({
    required this.clientId,
    required this.serverUrl,
  });

  // ============================================================
  // CONNECT SIGNALING SERVER
  // ============================================================

  Future<void> connectSignaling() async {
    if (_disposed) {
      return;
    }

    final wsUrl =
        '$serverUrl/api/ws/voip/signal/$clientId';

    try {
      onConnectionStateChanged?.call(
        'Connecting to signaling server...',
      );

      _socket = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      await _socket!.ready;

      if (_disposed) {
        return;
      }

      _socketSubscription = _socket!.stream.listen(
        _handleSignalingMessage,
        onError: (error) {
          if (_disposed) {
            return;
          }

          onError?.call(
            'Signaling error: $error',
          );
        },
        onDone: () {
          if (_disposed) {
            return;
          }

          onConnectionStateChanged?.call(
            'Signaling disconnected',
          );
        },
        cancelOnError: false,
      );

      onConnectionStateChanged?.call(
        'Signaling connected',
      );
    } catch (e) {
      onError?.call(
        'Could not connect to signaling server: $e',
      );
    }
  }

  // ============================================================
  // CREATE WEBRTC PEER CONNECTION
  // ============================================================

  Future<void> createPeerConnection() async {
    if (_disposed) {
      return;
    }

    try {
      onConnectionStateChanged?.call(
        'Creating WebRTC connection...',
      );

      final configuration = {
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
            ],
          },
        ],
      };

      // IMPORTANT:
      // Use the "webrtc." prefix so this calls the Flutter WebRTC
      // function instead of recursively calling this method.

      peerConnection =
          await webrtc.createPeerConnection(
        configuration,
      );

      if (_disposed) {
        return;
      }

      // ========================================================
      // ICE CANDIDATE
      // ========================================================

      peerConnection!.onIceCandidate =
          (webrtc.RTCIceCandidate candidate) {
        if (_disposed) {
          return;
        }

        if (peerId == null || roomId == null) {
          return;
        }

        _send({
          'type': 'ice_candidate',
          'room_id': roomId,
          'target_id': peerId,
          'candidate': candidate.toMap(),
        });
      };

      // ========================================================
      // PEER CONNECTION STATE
      // ========================================================

      peerConnection!.onConnectionState =
          (webrtc.RTCPeerConnectionState state) {
        if (_disposed) {
          return;
        }

        onConnectionStateChanged?.call(
          _connectionStateText(state),
        );
      };

      // ========================================================
      // ICE CONNECTION STATE
      // ========================================================

      peerConnection!.onIceConnectionState =
          (webrtc.RTCIceConnectionState state) {
        if (_disposed) {
          return;
        }

        onConnectionStateChanged?.call(
          'ICE: ${state.toString().split('.').last}',
        );
      };

      // ========================================================
      // REMOTE TRACK
      // ========================================================
      //
      // DO NOT create an RTCSessionDescription here.
      //
      // onTrack means actual remote media arrived.
      //

      peerConnection!.onTrack =
          (webrtc.RTCTrackEvent event) {
        if (_disposed) {
          return;
        }

        if (event.track.kind == 'audio') {
          onConnectionStateChanged?.call(
            'Remote audio connected',
          );
        }
      };

      onConnectionStateChanged?.call(
        'WebRTC connection created',
      );
    } catch (e) {
      onError?.call(
        'Could not create WebRTC connection: $e',
      );
    }
  }

  // ============================================================
  // CONNECTION STATE TEXT
  // ============================================================

  String _connectionStateText(
    webrtc.RTCPeerConnectionState state,
  ) {
    final value =
        state.toString().split('.').last;

    switch (value) {
      case 'RTCPeerConnectionStateNew':
        return 'WebRTC: New';

      case 'RTCPeerConnectionStateConnecting':
        return 'WebRTC: Connecting';

      case 'RTCPeerConnectionStateConnected':
        return 'WebRTC: Connected';

      case 'RTCPeerConnectionStateDisconnected':
        return 'WebRTC: Disconnected';

      case 'RTCPeerConnectionStateFailed':
        return 'WebRTC: Failed';

      case 'RTCPeerConnectionStateClosed':
        return 'WebRTC: Closed';

      default:
        return 'WebRTC: $value';
    }
  }

  // ============================================================
  // MICROPHONE
  // ============================================================

  Future<void> initializeMicrophone() async {
    if (_disposed) {
      return;
    }

    try {
      onConnectionStateChanged?.call(
        'Requesting microphone...',
      );

      localStream =
          await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      if (_disposed) {
        return;
      }

      if (peerConnection == null) {
        throw Exception(
          'Peer connection is not initialized',
        );
      }

      final audioTracks =
          localStream!.getAudioTracks();

      for (final track in audioTracks) {
        await peerConnection!.addTrack(
          track,
          localStream!,
        );
      }

      onConnectionStateChanged?.call(
        'Microphone ready',
      );
    } catch (e) {
      onError?.call(
        'Could not access microphone: $e',
      );
    }
  }

  // ============================================================
  // JOIN ROOM
  // ============================================================

  void joinRoom({
    required String room,
  }) {
    if (_disposed) {
      return;
    }

    roomId = room;

    _send({
      'type': 'join_room',
      'room_id': room,
    });

    onConnectionStateChanged?.call(
      'Joined room',
    );
  }

  // ============================================================
  // SIGNALING MESSAGE HANDLER
  // ============================================================

  Future<void> _handleSignalingMessage(
    dynamic rawMessage,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      final decoded =
          jsonDecode(rawMessage.toString());

      if (decoded is! Map) {
        return;
      }

      final message =
          Map<String, dynamic>.from(decoded);

      final type = message['type'];

      switch (type) {
        // ------------------------------------------------------
        // ROOM JOINED
        // ------------------------------------------------------

        case 'room_joined':
          _handleRoomJoined(message);
          break;

        // ------------------------------------------------------
        // PEER JOINED
        // ------------------------------------------------------

        case 'peer_joined':
        case 'peer_connected':
        case 'room_peer_joined':
          _handlePeerJoined(message);
          break;

        // ------------------------------------------------------
        // OFFER
        // ------------------------------------------------------

        case 'offer':
          await _handleOffer(message);
          break;

        // ------------------------------------------------------
        // ANSWER
        // ------------------------------------------------------

        case 'answer':
          await _handleAnswer(message);
          break;

        // ------------------------------------------------------
        // ICE CANDIDATE
        // ------------------------------------------------------

        case 'ice_candidate':
          await _handleIceCandidate(message);
          break;

        // ------------------------------------------------------
        // HANGUP
        // ------------------------------------------------------

        case 'hangup':
          _handleHangup();
          break;

        default:
          break;
      }
    } catch (e) {
      onError?.call(
        'Signaling message error: $e',
      );
    }
  }

  // ============================================================
  // ROOM JOINED
  // ============================================================

  void _handleRoomJoined(
    Map<String, dynamic> message,
  ) {
    final peers = message['peer_clients'];

    if (peers is List) {
      for (final peer in peers) {
        final id = peer.toString();

        if (id != clientId) {
          peerId = id;
          break;
        }
      }
    }

    if (peerId != null) {
      onConnectionStateChanged?.call(
        'Person connected',
      );
    }
  }

  // ============================================================
  // PEER JOINED
  // ============================================================

  void _handlePeerJoined(
    Map<String, dynamic> message,
  ) {
    final possiblePeerId =
        message['peer_id'] ??
        message['client_id'] ??
        message['sender_id'];

    if (possiblePeerId != null) {
      final id = possiblePeerId.toString();

      if (id != clientId) {
        peerId = id;

        onConnectionStateChanged?.call(
          'Person connected',
        );
      }
    }
  }

  // ============================================================
  // HANDLE OFFER
  // ============================================================

  Future<void> _handleOffer(
    Map<String, dynamic> message,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      // --------------------------------------------------------
      // IDENTIFY CALLER
      // --------------------------------------------------------

      peerId =
          message['sender_id']?.toString();

      if (peerId == null) {
        peerId =
            message['from']?.toString();
      }

      // --------------------------------------------------------
      // NOTIFY PERSON B
      // --------------------------------------------------------
      //
      // This is what allows real_call_screen.dart to change
      // its interface when Person A calls.
      //

      onIncomingCall?.call();

      // --------------------------------------------------------
      // READ OFFER
      // --------------------------------------------------------

      final rawOffer =
          message['offer'];

      if (rawOffer is! Map) {
        throw Exception(
          'Invalid offer received',
        );
      }

      final offerMap =
          Map<String, dynamic>.from(
        rawOffer,
      );

      final offer =
          webrtc.RTCSessionDescription(
        offerMap['sdp']?.toString() ?? '',
        offerMap['type']?.toString() ?? 'offer',
      );

      // --------------------------------------------------------
      // CREATE CONNECTION IF NEEDED
      // --------------------------------------------------------

      if (peerConnection == null) {
        await createPeerConnection();
      }

      if (peerConnection == null) {
        throw Exception(
          'Peer connection is not available',
        );
      }

      // --------------------------------------------------------
      // SET REMOTE DESCRIPTION
      // --------------------------------------------------------

      await peerConnection!.setRemoteDescription(
        offer,
      );

      _remoteDescriptionSet = true;

      onRemoteDescription?.call(
        offer,
      );

      // --------------------------------------------------------
      // ADD WAITING ICE CANDIDATES
      // --------------------------------------------------------

      await _addPendingIceCandidates();

      // --------------------------------------------------------
      // CREATE ANSWER
      // --------------------------------------------------------

      final answer =
          await peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      // --------------------------------------------------------
      // SET LOCAL DESCRIPTION
      // --------------------------------------------------------

      await peerConnection!.setLocalDescription(
        answer,
      );

      // --------------------------------------------------------
      // SEND ANSWER
      // --------------------------------------------------------

      _send({
        'type': 'answer',
        'room_id': roomId,
        'target_id': peerId,
        'answer': answer.toMap(),
      });

      onConnectionStateChanged?.call(
        'Incoming call answered',
      );
    } catch (e) {
      onError?.call(
        'Could not handle incoming call: $e',
      );
    }
  }

  // ============================================================
  // HANDLE ANSWER
  // ============================================================

  Future<void> _handleAnswer(
    Map<String, dynamic> message,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      peerId =
          message['sender_id']?.toString();

      if (peerId == null) {
        peerId =
            message['from']?.toString();
      }

      final rawAnswer =
          message['answer'];

      if (rawAnswer is! Map) {
        throw Exception(
          'Invalid answer received',
        );
      }

      final answerMap =
          Map<String, dynamic>.from(
        rawAnswer,
      );

      final answer =
          webrtc.RTCSessionDescription(
        answerMap['sdp']?.toString() ?? '',
        answerMap['type']?.toString() ?? 'answer',
      );

      if (peerConnection == null) {
        throw Exception(
          'Peer connection is not initialized',
        );
      }

      // --------------------------------------------------------
      // SET REMOTE ANSWER
      // --------------------------------------------------------

      await peerConnection!.setRemoteDescription(
        answer,
      );

      _remoteDescriptionSet = true;

      onRemoteDescription?.call(
        answer,
      );

      // --------------------------------------------------------
      // ADD WAITING ICE
      // --------------------------------------------------------

      await _addPendingIceCandidates();

      onConnectionStateChanged?.call(
        'Call connected',
      );
    } catch (e) {
      onError?.call(
        'Could not handle answer: $e',
      );
    }
  }

  // ============================================================
  // HANDLE ICE CANDIDATE
  // ============================================================

  Future<void> _handleIceCandidate(
    Map<String, dynamic> message,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      // --------------------------------------------------------
      // IDENTIFY SENDER
      // --------------------------------------------------------

      final sender =
          message['sender_id'];

      if (sender != null &&
          sender.toString() != clientId) {
        peerId = sender.toString();
      }

      // --------------------------------------------------------
      // READ CANDIDATE
      // --------------------------------------------------------

      final rawCandidate =
          message['candidate'];

      if (rawCandidate is! Map) {
        return;
      }

      final candidateMap =
          Map<String, dynamic>.from(
        rawCandidate,
      );

      final dynamic lineIndex =
          candidateMap['sdpMLineIndex'];

      int? parsedLineIndex;

      if (lineIndex is int) {
        parsedLineIndex = lineIndex;
      } else if (lineIndex != null) {
        parsedLineIndex =
            int.tryParse(
          lineIndex.toString(),
        );
      }

      final candidate =
          webrtc.RTCIceCandidate(
        candidateMap['candidate']?.toString(),
        candidateMap['sdpMid']?.toString(),
        parsedLineIndex,
      );

      // --------------------------------------------------------
      // IF REMOTE SDP IS NOT READY
      // --------------------------------------------------------
      //
      // Save ICE candidate until offer/answer is installed.
      //

      if (!_remoteDescriptionSet) {
        _pendingIceCandidates.add(
          candidate,
        );

        return;
      }

      // --------------------------------------------------------
      // ADD CANDIDATE
      // --------------------------------------------------------

      if (peerConnection != null) {
        await peerConnection!.addCandidate(
          candidate,
        );
      }

      onRemoteIceCandidate?.call(
        candidate,
      );
    } catch (e) {
      onError?.call(
        'Could not add ICE candidate: $e',
      );
    }
  }

  // ============================================================
  // ADD PENDING ICE CANDIDATES
  // ============================================================

  Future<void> _addPendingIceCandidates() async {
    if (peerConnection == null) {
      return;
    }

    if (_pendingIceCandidates.isEmpty) {
      return;
    }

    final candidates =
        List<webrtc.RTCIceCandidate>.from(
      _pendingIceCandidates,
    );

    _pendingIceCandidates.clear();

    for (final candidate in candidates) {
      try {
        await peerConnection!.addCandidate(
          candidate,
        );
      } catch (_) {
        // Ignore stale individual candidates.
      }
    }
  }

  // ============================================================
  // MAKE CALL
  // ============================================================

  Future<void> makeCall() async {
    if (_disposed) {
      throw Exception(
        'Call service has been disposed',
      );
    }

    if (_makingCall) {
      return;
    }

    if (peerConnection == null) {
      throw Exception(
        'Peer connection not initialized',
      );
    }

    if (peerId == null) {
      throw Exception(
        'Person B is not connected yet',
      );
    }

    if (roomId == null) {
      throw Exception(
        'Room is not initialized',
      );
    }

    try {
      _makingCall = true;

      onConnectionStateChanged?.call(
        'Creating call...',
      );

      // --------------------------------------------------------
      // CREATE OFFER
      // --------------------------------------------------------

      final offer =
          await peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      // --------------------------------------------------------
      // SET LOCAL DESCRIPTION
      // --------------------------------------------------------

      await peerConnection!.setLocalDescription(
        offer,
      );

      // --------------------------------------------------------
      // SEND OFFER
      // --------------------------------------------------------

      _send({
        'type': 'offer',
        'room_id': roomId,
        'target_id': peerId,
        'offer': offer.toMap(),
      });

      onConnectionStateChanged?.call(
        'Calling Person B...',
      );
    } finally {
      _makingCall = false;
    }
  }

  // ============================================================
  // HANG UP
  // ============================================================

  void hangUp() {
    if (_disposed) {
      return;
    }

    try {
      if (peerId != null &&
          roomId != null) {
        _send({
          'type': 'hangup',
          'room_id': roomId,
          'target_id': peerId,
        });
      }
    } catch (_) {}

    onCallEnded?.call();

    dispose();
  }

  // ============================================================
  // HANDLE REMOTE HANGUP
  // ============================================================

  void _handleHangup() {
    if (_disposed) {
      return;
    }

    onCallEnded?.call();
  }

  // ============================================================
  // SEND SIGNALING MESSAGE
  // ============================================================

  void _send(
    Map<String, dynamic> message,
  ) {
    if (_disposed) {
      return;
    }

    final socket = _socket;

    if (socket == null) {
      onError?.call(
        'Signaling socket is not connected',
      );
      return;
    }

    try {
      socket.sink.add(
        jsonEncode(message),
      );
    } catch (e) {
      onError?.call(
        'Could not send signaling message: $e',
      );
    }
  }

  // ============================================================
  // MUTE
  // ============================================================

  void setMuted(bool muted) {
    final stream = localStream;

    if (stream == null) {
      return;
    }

    for (final track in stream.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    // ----------------------------------------------------------
    // RESET INTERNAL STATE
    // ----------------------------------------------------------

    _remoteDescriptionSet = false;
    _makingCall = false;

    _pendingIceCandidates.clear();

    // ----------------------------------------------------------
    // CLOSE WEBSOCKET LISTENER
    // ----------------------------------------------------------

    try {
      await _socketSubscription?.cancel();
    } catch (_) {}

    _socketSubscription = null;

    // ----------------------------------------------------------
    // CLOSE WEBSOCKET
    // ----------------------------------------------------------

    try {
      await _socket?.sink.close();
    } catch (_) {}

    _socket = null;

    // ----------------------------------------------------------
    // STOP MICROPHONE
    // ----------------------------------------------------------

    try {
      final tracks =
          localStream?.getTracks() ?? [];

      for (final track in tracks) {
        try {
          await track.stop();
        } catch (_) {}
      }
    } catch (_) {}

    // ----------------------------------------------------------
    // DISPOSE LOCAL STREAM
    // ----------------------------------------------------------

    try {
      await localStream?.dispose();
    } catch (_) {}

    localStream = null;

    // ----------------------------------------------------------
    // CLOSE PEER CONNECTION
    // ----------------------------------------------------------

    try {
      await peerConnection?.close();
    } catch (_) {}

    peerConnection = null;

    // ----------------------------------------------------------
    // CLEAR IDs
    // ----------------------------------------------------------

    roomId = null;
    peerId = null;
  }
}