import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';
import '../models/session_info.dart';

import 'signaling_server.dart' show ApprovalCallback, SignalingMessageCallback;

/// CloudSignalingService enables WebRTC signaling over the public Internet
/// across cellular networks (4G/5G) and any Wi-Fi networks using a shared 6-digit Room Code.
class CloudSignalingService {
  static const String brokerHost = 'broker.hivemq.com';
  static const int brokerPort = 1883;

  MqttServerClient? _client;
  SessionInfo? _sessionInfo;
  String? _currentRoomCode;
  bool _isHost = false;
  bool _isConnected = false;

  // Host callbacks
  ApprovalCallback? onApprovalRequested;
  void Function(String deviceName)? onClientApproved;
  void Function()? onClientDisconnected;

  // Viewer callbacks
  void Function()? onApproved;
  void Function(String reason)? onRejected;
  void Function(String reason)? onAuthFailed;
  void Function()? onDisconnected;

  // Common callback
  SignalingMessageCallback? onSignalingMessage;

  bool get isConnected => _isConnected && _client?.connectionStatus?.state == MqttConnectionState.connected;
  SessionInfo? get sessionInfo => _sessionInfo;
  String? get currentRoomCode => _currentRoomCode;

  // ==========================================
  // HOST (DEVICE A / SENDER)
  // ==========================================

  Future<SessionInfo> startHost({
    String deviceName = 'Phone A (Host)',
  }) async {
    await disconnect();
    _isHost = true;

    final random = Random.secure();
    // Generate an easy-to-read 6-digit Room Code
    final roomCode = (100000 + random.nextInt(900000)).toString();
    final pin = roomCode; // Single 6-digit code serves as room ID & auth PIN
    final sessionId = const Uuid().v4();

    _currentRoomCode = roomCode;
    _sessionInfo = SessionInfo(
      ip: 'Internet Cloud',
      port: brokerPort,
      sessionId: sessionId,
      pin: pin,
      roomCode: roomCode,
      isInternetMode: true,
      deviceName: deviceName,
    );

    final clientId = 'vizilink_h_${roomCode}_${random.nextInt(9999)}';
    await _connectMqtt(clientId);

    final subTopic = 'vizilink/rooms/$roomCode/to_host';
    _client!.subscribe(subTopic, MqttQos.atLeastOnce);
    debugPrint('CloudSignaling: Host listening on $subTopic');

    return _sessionInfo!;
  }

  // ==========================================
  // VIEWER (DEVICE B / RECEIVER)
  // ==========================================

  Future<void> connectViewer({
    required String roomCode,
    String? pin,
    String deviceName = 'Phone B (Viewer)',
  }) async {
    await disconnect();
    _isHost = false;
    _currentRoomCode = roomCode.trim().replaceAll(' ', '');

    final random = Random.secure();
    final clientId = 'vizilink_v_${_currentRoomCode}_${random.nextInt(9999)}';
    await _connectMqtt(clientId);

    final subTopic = 'vizilink/rooms/$_currentRoomCode/to_viewer';
    _client!.subscribe(subTopic, MqttQos.atLeastOnce);
    debugPrint('CloudSignaling: Viewer listening on $subTopic');

    // Send join request to host
    sendSignalingMessage({
      'type': 'join',
      'pin': pin ?? _currentRoomCode,
      'deviceName': deviceName,
    });
  }

  // ==========================================
  // COMMON MQTT CONNECTION & MESSAGING
  // ==========================================

  Future<void> _connectMqtt(String clientId) async {
    _client = MqttServerClient.withPort(brokerHost, clientId, brokerPort);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    _client!.connectionMessage = connMessage;

    try {
      final status = await _client!.connect().timeout(const Duration(seconds: 15));
      if (status?.state != MqttConnectionState.connected) {
        throw Exception('Failed to connect to cloud signaling broker (${status?.state})');
      }
      _isConnected = true;

      _client!.updates?.listen(_handleIncomingMessages);
    } catch (e) {
      debugPrint('CloudSignaling connection error: $e');
      _isConnected = false;
      throw Exception('Could not connect to Internet signaling service. Check your internet connection.');
    }
  }

  void _handleIncomingMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final pubMsg = msg.payload as MqttPublishMessage;
      String payloadString;
      try {
        payloadString = utf8.decode(pubMsg.payload.message);
      } catch (_) {
        payloadString = MqttPublishPayload.bytesToStringAsString(pubMsg.payload.message);
      }

      try {
        final message = jsonDecode(payloadString) as Map<String, dynamic>;
        final type = message['type'] as String?;

        if (_isHost) {
          _handleHostMessage(message, type);
        } else {
          _handleViewerMessage(message, type);
        }
      } catch (e) {
        debugPrint('CloudSignaling JSON parse error: $e');
      }
    }
  }

  void _handleHostMessage(Map<String, dynamic> message, String? type) async {
    if (type == 'join') {
      final clientPin = message['pin'] as String?;
      final clientDevice = (message['deviceName'] as String?) ?? 'Remote Viewer';

      // Verify PIN match
      if (clientPin != _sessionInfo?.pin && clientPin != _sessionInfo?.roomCode) {
        sendSignalingMessage({
          'type': 'auth_failed',
          'reason': 'Invalid Room Code or PIN',
        });
        return;
      }

      // Safe user consent check on Host
      bool approved = true;
      if (onApprovalRequested != null) {
        try {
          approved = await onApprovalRequested!(clientDevice);
        } catch (e) {
          debugPrint('Approval prompt failed or unmounted: $e. Auto-approving with valid PIN.');
          approved = true;
        }
      }

      if (approved) {
        sendSignalingMessage({'type': 'connection_approved'});
      } else {
        sendSignalingMessage({
          'type': 'connection_rejected',
          'reason': 'Host user declined connection',
        });
      }
    } else if (type == 'ready_for_stream') {
      final clientDevice = (message['deviceName'] as String?) ?? 'Remote Viewer';
      onClientApproved?.call(clientDevice);
    } else if (type == 'disconnect') {
      onClientDisconnected?.call();
    } else {
      onSignalingMessage?.call(message);
    }
  }

  void _handleViewerMessage(Map<String, dynamic> message, String? type) {
    if (type == 'connection_approved') {
      onApproved?.call();
      // Inform host we are ready to receive stream
      sendSignalingMessage({
        'type': 'ready_for_stream',
        'deviceName': 'Phone B (Viewer)',
      });
    } else if (type == 'connection_rejected') {
      final reason = (message['reason'] as String?) ?? 'Host declined connection';
      onRejected?.call(reason);
      disconnect();
    } else if (type == 'auth_failed') {
      final reason = (message['reason'] as String?) ?? 'Authentication failed';
      onAuthFailed?.call(reason);
      disconnect();
    } else if (type == 'disconnect') {
      onDisconnected?.call();
    } else {
      onSignalingMessage?.call(message);
    }
  }

  /// Sends a signaling message to the peer.
  void sendSignalingMessage(Map<String, dynamic> message) {
    if (_client == null || _currentRoomCode == null || !_isConnected) return;

    final targetTopic = _isHost
        ? 'vizilink/rooms/$_currentRoomCode/to_viewer'
        : 'vizilink/rooms/$_currentRoomCode/to_host';

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    try {
      _client!.publishMessage(targetTopic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      debugPrint('CloudSignaling publish error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      if (_isConnected && _currentRoomCode != null) {
        try {
          sendSignalingMessage({'type': 'disconnect'});
        } catch (_) {}
      }
      _client!.disconnect();
      _client = null;
    }
    _isConnected = false;
    _currentRoomCode = null;
    _sessionInfo = null;
  }
}
