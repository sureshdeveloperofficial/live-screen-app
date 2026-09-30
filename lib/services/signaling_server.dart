import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/session_info.dart';

typedef ApprovalCallback = Future<bool> Function(String deviceName);
typedef SignalingMessageCallback = void Function(Map<String, dynamic> message);

class SignalingServer {
  HttpServer? _server;
  WebSocket? _connectedClient;
  SessionInfo? _sessionInfo;

  ApprovalCallback? onApprovalRequested;
  void Function(String deviceName)? onClientApproved;
  SignalingMessageCallback? onSignalingMessage;
  void Function()? onClientDisconnected;

  bool get isRunning => _server != null;
  SessionInfo? get sessionInfo => _sessionInfo;
  bool get hasConnectedClient => _connectedClient != null;

  /// Starts the embedded signaling server on the specified IP and port.
  Future<SessionInfo> start({
    required String hostIp,
    int port = 8888,
    String deviceName = 'Phone A (Host)',
  }) async {
    await stop();

    // Generate ephemeral PIN & Session ID
    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();
    final sessionId = const Uuid().v4();

    _sessionInfo = SessionInfo(
      ip: hostIp,
      port: port,
      sessionId: sessionId,
      pin: pin,
      deviceName: deviceName,
    );

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleHttpRequest);

    return _sessionInfo!;
  }

  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((WebSocket ws) {
        _handleClientConnection(ws);
      }).catchError((err) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      });
    } else {
      // Basic HTTP health / discovery check
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'app': 'ViziLink Security Lab',
          'status': 'ready',
          'sessionId': _sessionInfo?.sessionId,
        }))
        ..close();
    }
  }

  void _handleClientConnection(WebSocket ws) {
    // If a client is already connected, reject concurrent connections for security
    if (_connectedClient != null) {
      ws.add(jsonEncode({
        'type': 'error',
        'message': 'Host already has an active mirroring session',
      }));
      ws.close(WebSocketStatus.policyViolation, 'Single viewer policy');
      return;
    }

    _connectedClient = ws;

    ws.listen(
      (data) async {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          final type = message['type'] as String?;

          if (type == 'join') {
            final clientPin = message['pin'] as String?;
            final clientDevice = (message['deviceName'] as String?) ?? 'Viewer Device';

            if (clientPin != _sessionInfo?.pin) {
              sendToClient({
                'type': 'auth_failed',
                'reason': 'Invalid Session PIN. Connection refused.',
              });
              ws.close(WebSocketStatus.policyViolation, 'Invalid PIN');
              _connectedClient = null;
              return;
            }

            // Explicit user consent gate: Phone A must approve connection
            bool approved = false;
            if (onApprovalRequested != null) {
              approved = await onApprovalRequested!(clientDevice);
            } else {
              approved = true;
            }

            if (!approved) {
              sendToClient({
                'type': 'connection_rejected',
                'reason': 'Host declined screen mirroring request.',
              });
              ws.close(WebSocketStatus.normalClosure, 'Host declined');
              _connectedClient = null;
              return;
            }

            sendToClient({
              'type': 'connection_approved',
              'sessionId': _sessionInfo?.sessionId,
            });
            onClientApproved?.call(clientDevice);
          } else {
            // Forward signaling messages (offer, answer, candidate) to WebRTC handler
            onSignalingMessage?.call(message);
          }
        } catch (_) {}
      },
      onDone: () {
        _connectedClient = null;
        onClientDisconnected?.call();
      },
      onError: (_) {
        _connectedClient = null;
        onClientDisconnected?.call();
      },
    );
  }

  /// Sends a signaling payload to the connected viewer client.
  void sendToClient(Map<String, dynamic> message) {
    if (_connectedClient != null && _connectedClient!.readyState == WebSocket.open) {
      _connectedClient!.add(jsonEncode(message));
    }
  }

  /// Stops server and disconnects any active clients.
  Future<void> stop() async {
    try {
      if (_connectedClient != null) {
        await _connectedClient!.close(WebSocketStatus.normalClosure, 'Server stopped');
        _connectedClient = null;
      }
      await _server?.close(force: true);
      _server = null;
      _sessionInfo = null;
    } catch (_) {}
  }
}
