import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef SignalingMessageCallback = void Function(Map<String, dynamic> message);

class SignalingClient {
  WebSocket? _socket;
  bool _isConnected = false;

  SignalingMessageCallback? onSignalingMessage;
  void Function()? onApproved;
  void Function(String reason)? onRejected;
  void Function(String reason)? onAuthFailed;
  void Function()? onDisconnected;

  bool get isConnected => _isConnected && _socket != null;

  /// Connects to Phone A's signaling server and sends join handshake.
  Future<void> connect({
    required String ip,
    required int port,
    required String pin,
    String deviceName = 'Phone B (Viewer)',
  }) async {
    await disconnect();

    final uri = Uri.parse('ws://$ip:$port/ws');
    try {
      _socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 10));

      _isConnected = true;

      // Send join message
      _socket!.add(jsonEncode({
        'type': 'join',
        'pin': pin,
        'deviceName': deviceName,
      }));

      _socket!.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            final type = message['type'] as String?;

            if (type == 'connection_approved') {
              onApproved?.call();
            } else if (type == 'connection_rejected') {
              final reason = (message['reason'] as String?) ?? 'Host declined';
              onRejected?.call(reason);
              disconnect();
            } else if (type == 'auth_failed') {
              final reason = (message['reason'] as String?) ?? 'Authentication failed';
              onAuthFailed?.call(reason);
              disconnect();
            } else {
              onSignalingMessage?.call(message);
            }
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          onDisconnected?.call();
        },
        onError: (_) {
          _isConnected = false;
          onDisconnected?.call();
        },
      );
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  /// Sends a signaling payload to Phone A.
  void send(Map<String, dynamic> message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(jsonEncode(message));
    }
  }

  /// Disconnects from Phone A.
  Future<void> disconnect() async {
    try {
      _isConnected = false;
      await _socket?.close();
      _socket = null;
    } catch (_) {}
  }
}
