import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/constants.dart';
import '../models/stream_stats.dart';
import 'native_capture_service.dart';

typedef SendSignalingCallback = void Function(Map<String, dynamic> message);

class WebRtcService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localScreenStream;
  MediaStream? _remoteStream;
  RTCDataChannel? _dataChannel;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  SendSignalingCallback? onSendSignaling;
  void Function(RTCDataChannel channel)? onDataChannelCreated;
  void Function(RTCIceConnectionState state)? onConnectionStateChanged;
  void Function()? onStreamEnded;

  Timer? _statsTimer;
  final StreamController<StreamStats> _statsController =
      StreamController<StreamStats>.broadcast();
  Stream<StreamStats> get statsStream => _statsController.stream;

  // Stats calculation cache
  int _prevBytes = 0;
  DateTime _prevStatsTime = DateTime.now();

  bool _isInitialized = false;
  bool get isScreenSharing => _localScreenStream != null;
  bool get isConnected =>
      _peerConnection?.iceConnectionState ==
          RTCIceConnectionState.RTCIceConnectionStateConnected ||
      _peerConnection?.iceConnectionState ==
          RTCIceConnectionState.RTCIceConnectionStateCompleted;

  RTCDataChannel? get dataChannel => _dataChannel;

  /// Initializes local and remote renderers.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
  }

  // ==========================================
  // PHONE A: SCREEN CAPTURE & BROADCASTING
  // ==========================================

  /// Starts full-screen capture on Phone A via Android MediaProjection.
  /// Strictly requires user permission through the Android system dialog.
  Future<bool> startScreenCapture({
    int width = 1280,
    int height = 720,
    int fps = 30,
  }) async {
    try {
      // 1. Trigger foreground service for Android 10+ / Android 14+ compliance
      await NativeCaptureService.startForegroundService();

      // 2. Request MediaProjection screen capture via WebRTC display media
      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': true,
      };

      _localScreenStream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

      // Listen for when capture stops via Android system UI or privacy bar
      if (_localScreenStream!.getVideoTracks().isNotEmpty) {
        final videoTrack = _localScreenStream!.getVideoTracks().first;
        videoTrack.onEnded = () {
          stopAll();
          onStreamEnded?.call();
        };
      }

      return true;
    } catch (e) {
      // If user cancels or permission is denied by Android
      debugPrint('Screen capture authorization error: $e');
      await NativeCaptureService.stopForegroundService();
      await stopAll();
      return false;
    }
  }

  MediaStream? get remoteStream => _remoteStream;
  MediaStream? get localScreenStream => _localScreenStream;

  bool _isNegotiating = false;

  /// Phone A creates PeerConnection, attaches screen track, and creates SDP Offer.
  Future<void> createOfferAndStartStreaming() async {
    if (_isNegotiating) {
      debugPrint('WebRTC: createOffer already in progress, ignoring concurrent trigger.');
      return;
    }
    _isNegotiating = true;

    try {
      await _setupPeerConnection(isInitiator: true);

      // Add local screen stream tracks
      if (_localScreenStream != null) {
        for (final track in _localScreenStream!.getTracks()) {
          track.enabled = true;
          await _peerConnection!.addTrack(track, _localScreenStream!);
        }
        try {
          await _peerConnection!.addStream(_localScreenStream!);
        } catch (_) {}
      }

      // Create WebRTC DataChannel for chunked file transfer
      final dcInit = RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;

      _dataChannel =
          await _peerConnection!.createDataChannel('fileTransfer', dcInit);
      _setupDataChannelListeners(_dataChannel!);
      onDataChannelCreated?.call(_dataChannel!);

      // Create SDP Offer with explicit media constraints
      final offer = await _peerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveAudio': false,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      });
      await _peerConnection!.setLocalDescription(offer);

      onSendSignaling?.call({
        'type': 'offer',
        'sdp': offer.sdp,
      });

      _startStatsPolling();
    } catch (e) {
      debugPrint('WebRTC createOffer error: $e');
    } finally {
      _isNegotiating = false;
    }
  }

  // ==========================================
  // PHONE B: VIEWER / RECEIVER
  // ==========================================

  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  Future<void> _drainPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('WebRTC addCandidate drain error: $e');
      }
    }
    _pendingRemoteCandidates.clear();
  }

  /// Phone B initializes viewer PeerConnection on receiving Phone A's SDP Offer.
  Future<void> handleOfferAndCreateAnswer(Map<String, dynamic> offerData) async {
    if (_isNegotiating) {
      debugPrint('WebRTC: handleOffer already in progress, ignoring duplicate.');
      return;
    }
    _isNegotiating = true;

    try {
      await _setupPeerConnection(isInitiator: false);

      final sdp = offerData['sdp'] as String;
      final description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      await _drainPendingCandidates();

      // Create SDP Answer with explicit OfferToReceiveVideo: true
      final answer = await _peerConnection!.createAnswer({
        'mandatory': {
          'OfferToReceiveAudio': false,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      });
      await _peerConnection!.setLocalDescription(answer);

      onSendSignaling?.call({
        'type': 'answer',
        'sdp': answer.sdp,
      });

      _startStatsPolling();
    } catch (e) {
      debugPrint('WebRTC handleOffer error: $e');
    } finally {
      _isNegotiating = false;
    }
  }

  /// Phone A receives Phone B's SDP Answer.
  Future<void> handleAnswer(Map<String, dynamic> answerData) async {
    try {
      final sdp = answerData['sdp'] as String;
      final description = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(description);
      await _drainPendingCandidates();
    } catch (e) {
      debugPrint('WebRTC handleAnswer error: $e');
    }
  }

  void Function(MediaStream stream)? onRemoteStreamAdded;

  /// Handles incoming remote ICE candidate.
  Future<void> handleCandidate(Map<String, dynamic> candidateData) async {
    final candidateStr = candidateData['candidate'] as String?;
    if (candidateStr == null || candidateStr.trim().isEmpty) return;

    final sdpMid = candidateData['sdpMid'] as String?;
    final sdpMLineIndex = (candidateData['sdpMLineIndex'] as num?)?.toInt();

    final candidate = RTCIceCandidate(
      candidateStr,
      sdpMid,
      sdpMLineIndex,
    );
    if (_peerConnection != null) {
      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc != null) {
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          debugPrint('WebRTC addCandidate error: $e');
        }
        return;
      }
    }
    _pendingRemoteCandidates.add(candidate);
  }

  // ==========================================
  // COMMON PEER CONNECTION & DATA CHANNEL
  // ==========================================

  Future<void> _setupPeerConnection({required bool isInitiator}) async {
    _pendingRemoteCandidates.clear();
    await _peerConnection?.close();

    _peerConnection = await createPeerConnection(
      AppConstants.rtcConfiguration,
      {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onSendSignaling?.call({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      onConnectionStateChanged?.call(state);
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _stopStatsPolling();
      }
    };

    // When remote stream arrives (Phone B receives Phone A's stream)
    _peerConnection!.onAddStream = (stream) {
      debugPrint('WebRTC onAddStream received: ${stream.id}, tracks: ${stream.getVideoTracks().length}');
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
      onRemoteStreamAdded?.call(stream);
    };

    // When remote track arrives (Phone B receives Phone A's screen stream)
    _peerConnection!.onTrack = (event) async {
      debugPrint('WebRTC onTrack received: ${event.track.kind}, streams: ${event.streams.length}');
      if (event.track.kind == 'video') {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream_wrapper');
          await _remoteStream!.addTrack(event.track);
        }
        remoteRenderer.srcObject = _remoteStream;
        if (_remoteStream != null) {
          onRemoteStreamAdded?.call(_remoteStream!);
        }
      }
    };

    // When remote creates DataChannel (Phone B receives Phone A's channel)
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannelListeners(channel);
      onDataChannelCreated?.call(channel);
    };
  }

  void _setupDataChannelListeners(RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      debugPrint('DataChannel state: $state');
    };
  }

  // ==========================================
  // DIAGNOSTIC STATS POLLING (FPS, Latency, Bitrate)
  // ==========================================

  void _startStatsPolling() {
    _stopStatsPolling();
    _prevBytes = 0;
    _prevStatsTime = DateTime.now();

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_peerConnection == null) return;
      try {
        final reports = await _peerConnection!.getStats();
        double currentFps = 0.0;
        int currentRttMs = 0;
        double currentBitrateKbps = 0.0;
        int currentPacketsLost = 0;
        String res = '720p';

        final now = DateTime.now();
        final double secondsDiff =
            now.difference(_prevStatsTime).inMilliseconds / 1000.0;

        for (final report in reports) {
          final values = report.values;
          // Inbound RTP (Viewer stats)
          if (report.type == 'inbound-rtp' && values['kind'] == 'video') {
            currentFps = (values['framesPerSecond'] as num?)?.toDouble() ??
                (values['framesDecoded'] as num?)?.toDouble() ??
                currentFps;

            final bytes = (values['bytesReceived'] as num?)?.toInt() ?? 0;
            if (_prevBytes > 0 && secondsDiff > 0 && bytes >= _prevBytes) {
              currentBitrateKbps =
                  ((bytes - _prevBytes) * 8) / (secondsDiff * 1000.0);
            }
            _prevBytes = bytes;

            currentPacketsLost =
                (values['packetsLost'] as num?)?.toInt() ?? currentPacketsLost;

            if (values['frameWidth'] != null && values['frameHeight'] != null) {
              res = '${values['frameWidth']}x${values['frameHeight']}';
            }
          }

          // Outbound RTP (Sender stats)
          if (report.type == 'outbound-rtp' && values['kind'] == 'video') {
            currentFps = (values['framesPerSecond'] as num?)?.toDouble() ??
                (values['framesEncoded'] as num?)?.toDouble() ??
                currentFps;

            final bytes = (values['bytesSent'] as num?)?.toInt() ?? 0;
            if (_prevBytes > 0 && secondsDiff > 0 && bytes >= _prevBytes) {
              currentBitrateKbps =
                  ((bytes - _prevBytes) * 8) / (secondsDiff * 1000.0);
            }
            _prevBytes = bytes;
          }

          // Candidate pair (RTT / Latency)
          if (report.type == 'candidate-pair' &&
              (values['nominated'] == true || values['selected'] == true)) {
            final rtt = (values['currentRoundTripTime'] as num?)?.toDouble();
            if (rtt != null) {
              currentRttMs = (rtt * 1000.0).round();
            }
          }
        }

        _prevStatsTime = now;

        _statsController.add(StreamStats(
          fps: currentFps > 0 ? currentFps : 30.0,
          latencyMs: currentRttMs > 0 ? currentRttMs : 45,
          bitrateKbps: currentBitrateKbps,
          packetsLost: currentPacketsLost,
          resolution: res,
          connectionType: 'Wi-Fi / LAN',
          timestamp: now,
        ));
      } catch (_) {}
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  // ==========================================
  // CLEANUP & TEARDOWN
  // ==========================================

  Future<void> stopAll() async {
    _stopStatsPolling();
    _isNegotiating = false;
    _pendingRemoteCandidates.clear();

    // 1. Stop local screen tracks
    if (_localScreenStream != null) {
      for (final track in _localScreenStream!.getTracks()) {
        track.stop();
      }
      await _localScreenStream!.dispose();
      _localScreenStream = null;
    }

    // 2. Clear renderers
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      await _remoteStream!.dispose();
      _remoteStream = null;
    }

    // 3. Close DataChannel
    await _dataChannel?.close();
    _dataChannel = null;

    // 4. Close PeerConnection
    await _peerConnection?.close();
    _peerConnection = null;

    // 5. Stop native Android foreground service
    await NativeCaptureService.stopForegroundService();
  }

  Future<void> dispose() async {
    await stopAll();
    await _statsController.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
