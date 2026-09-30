import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../models/stream_stats.dart';
import 'cloud_signaling_service.dart';
import 'file_transfer_service.dart';
import 'native_capture_service.dart';
import 'network_service.dart';
import 'signaling_client.dart';
import 'signaling_server.dart';
import 'webrtc_service.dart';

enum AppRole { none, sender, viewer }

class AppController extends ChangeNotifier {
  static final AppController instance = AppController._internal();
  AppController._internal();

  final WebRtcService webrtcService = WebRtcService();
  final CloudSignalingService cloudSignaling = CloudSignalingService();
  final SignalingServer signalingServer = SignalingServer();
  final SignalingClient signalingClient = SignalingClient();
  final FileTransferService fileTransferService = FileTransferService();

  bool useInternetMode = true; // Default: Works across cellular 4G/5G & any Wi-Fi

  AppRole _role = AppRole.none;
  AppRole get role => _role;

  SessionInfo? _activeSession;
  SessionInfo? get activeSession => _activeSession;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  StreamStats _currentStats = StreamStats.initial();
  StreamStats get currentStats => _currentStats;

  // Settings
  int targetFps = 30;
  int videoWidth = 1280;
  int videoHeight = 720;
  int bitrateKbps = 2500;

  Future<void> initialize() async {
    NativeCaptureService.initialize();
    await webrtcService.initialize();

    // Listen for native capture stopped broadcast (e.g. from system notification)
    NativeCaptureService.onCaptureStopped.listen((_) {
      stopSession();
    });

    // Wire up WebRTC stats
    webrtcService.statsStream.listen((stats) {
      _currentStats = stats;
      notifyListeners();
    });

    // Wire up DataChannel to FileTransferService
    webrtcService.onDataChannelCreated = (channel) {
      fileTransferService.attachDataChannel(channel);
    };

    // Wire up WebRTC stream ended
    webrtcService.onStreamEnded = () {
      stopSession();
    };

    // Rebuild UI when remote video track arrives
    webrtcService.onRemoteStreamAdded = (_) {
      notifyListeners();
    };
  }

  // ==========================================
  // SENDER ACTIONS (Phone A)
  // ==========================================

  Future<SessionInfo?> startHostSession({
    required ApprovalCallback onApprovalPrompt,
  }) async {
    _role = AppRole.sender;

    if (useInternetMode) {
      cloudSignaling.onApprovalRequested = onApprovalPrompt;

      cloudSignaling.onClientApproved = (clientDevice) async {
        _connectedDeviceName = clientDevice;
        notifyListeners();
        if (!webrtcService.isScreenSharing) {
          final started = await startScreenSharing();
          if (!started) {
            cloudSignaling.sendSignalingMessage({
              'type': 'stream_error',
              'message': 'Screen capture authorization was cancelled or denied on Phone A',
            });
          }
        } else {
          await webrtcService.createOfferAndStartStreaming();
        }
      };

      cloudSignaling.onSignalingMessage = (msg) async {
        final type = msg['type'] as String?;
        if (type == 'answer') {
          await webrtcService.handleAnswer(msg);
        } else if (type == 'candidate') {
          await webrtcService.handleCandidate(msg);
        }
      };

      cloudSignaling.onClientDisconnected = () {
        _connectedDeviceName = null;
        _isStreaming = false;
        notifyListeners();
      };

      webrtcService.onSendSignaling = (msg) {
        cloudSignaling.sendSignalingMessage(msg);
      };

      _activeSession = await cloudSignaling.startHost(
        deviceName: 'Phone A (Sender)',
      );
    } else {
      // Local LAN fallback mode
      final ip = await NetworkService.getLocalIpAddress() ?? '127.0.0.1';

      signalingServer.onApprovalRequested = onApprovalPrompt;

      signalingServer.onClientApproved = (clientDevice) async {
        _connectedDeviceName = clientDevice;
        notifyListeners();
        if (webrtcService.isScreenSharing) {
          await webrtcService.createOfferAndStartStreaming();
        }
      };

      signalingServer.onSignalingMessage = (msg) async {
        final type = msg['type'] as String?;
        if (type == 'ready_for_stream') {
          if (webrtcService.isScreenSharing) {
            await webrtcService.createOfferAndStartStreaming();
          }
        } else if (type == 'answer') {
          await webrtcService.handleAnswer(msg);
        } else if (type == 'candidate') {
          await webrtcService.handleCandidate(msg);
        }
      };

      signalingServer.onClientDisconnected = () {
        _connectedDeviceName = null;
        _isStreaming = false;
        notifyListeners();
      };

      webrtcService.onSendSignaling = (msg) {
        signalingServer.sendToClient(msg);
      };

      _activeSession = await signalingServer.start(
        hostIp: ip,
        deviceName: 'Phone A (Sender)',
      );
    }

    notifyListeners();
    return _activeSession;
  }

  /// Triggers Android MediaProjection authorization & starts WebRTC stream
  Future<bool> startScreenSharing() async {
    final success = await webrtcService.startScreenCapture(
      width: videoWidth,
      height: videoHeight,
      fps: targetFps,
    );

    if (!success) {
      return false;
    }

    _isStreaming = true;
    notifyListeners();

    if (useInternetMode) {
      if (cloudSignaling.isConnected && _connectedDeviceName != null) {
        await webrtcService.createOfferAndStartStreaming();
      }
    } else {
      if (signalingServer.hasConnectedClient) {
        await webrtcService.createOfferAndStartStreaming();
      }
    }
    return true;
  }

  // ==========================================
  // VIEWER ACTIONS (Phone B)
  // ==========================================

  Future<void> connectAsViewer({
    required String roomCodeOrIp,
    int port = 8888,
    String? pin,
    required VoidCallback onApproved,
    required Function(String reason) onRejected,
    required Function(String reason) onAuthFailed,
  }) async {
    _role = AppRole.viewer;
    final cleanCode = roomCodeOrIp.trim().replaceAll(' ', '');
    final isInternet = useInternetMode || !cleanCode.contains('.');

    _activeSession = SessionInfo(
      ip: isInternet ? 'Internet Cloud' : cleanCode,
      port: port,
      sessionId: '',
      pin: pin ?? cleanCode,
      roomCode: cleanCode,
      isInternetMode: isInternet,
      deviceName: 'Phone A (Remote)',
    );

    if (isInternet) {
      cloudSignaling.onApproved = () {
        _isStreaming = true;
        _connectedDeviceName = 'Phone A (Host)';
        notifyListeners();
        onApproved();
      };

      cloudSignaling.onRejected = (reason) {
        _isStreaming = false;
        notifyListeners();
        onRejected(reason);
      };

      cloudSignaling.onAuthFailed = (reason) {
        _isStreaming = false;
        notifyListeners();
        onAuthFailed(reason);
      };

      cloudSignaling.onDisconnected = () {
        stopSession();
      };

      cloudSignaling.onSignalingMessage = (msg) async {
        final type = msg['type'] as String?;
        if (type == 'offer') {
          await webrtcService.handleOfferAndCreateAnswer(msg);
        } else if (type == 'candidate') {
          await webrtcService.handleCandidate(msg);
        } else if (type == 'stream_error' || type == 'capture_denied') {
          final errorMsg = msg['message'] as String? ??
              'Screen capture authorization was cancelled or denied on Phone A';
          _isStreaming = false;
          notifyListeners();
          onRejected(errorMsg);
        }
      };

      webrtcService.onSendSignaling = (msg) {
        cloudSignaling.sendSignalingMessage(msg);
      };

      await cloudSignaling.connectViewer(
        roomCode: cleanCode,
        pin: pin,
        deviceName: 'Phone B (Viewer)',
      );
    } else {
      // Local LAN mode
      signalingClient.onApproved = () {
        _isStreaming = true;
        _connectedDeviceName = 'Phone A';
        notifyListeners();
        onApproved();
        signalingClient.send({'type': 'ready_for_stream'});
      };

      signalingClient.onRejected = (reason) {
        _isStreaming = false;
        notifyListeners();
        onRejected(reason);
      };

      signalingClient.onAuthFailed = (reason) {
        _isStreaming = false;
        notifyListeners();
        onAuthFailed(reason);
      };

      signalingClient.onDisconnected = () {
        stopSession();
      };

      signalingClient.onSignalingMessage = (msg) async {
        final type = msg['type'] as String?;
        if (type == 'offer') {
          await webrtcService.handleOfferAndCreateAnswer(msg);
        } else if (type == 'candidate') {
          await webrtcService.handleCandidate(msg);
        }
      };

      webrtcService.onSendSignaling = (msg) {
        signalingClient.send(msg);
      };

      await signalingClient.connect(
        ip: cleanCode,
        port: port,
        pin: pin ?? '',
        deviceName: 'Phone B (Viewer)',
      );
    }

    notifyListeners();
  }

  // ==========================================
  // TEARDOWN & DISCONNECT
  // ==========================================

  Future<void> stopSession() async {
    _isStreaming = false;
    _connectedDeviceName = null;
    _activeSession = null;
    _currentStats = StreamStats.initial();

    await webrtcService.stopAll();
    await cloudSignaling.disconnect();
    await signalingServer.stop();
    await signalingClient.disconnect();

    _role = AppRole.none;
    notifyListeners();
  }

  @override
  void dispose() {
    webrtcService.dispose();
    fileTransferService.dispose();
    super.dispose();
  }
}
