import 'dart:convert';

class SessionInfo {
  final String ip;
  final int port;
  final String sessionId;
  final String pin;
  final String roomCode;
  final bool isInternetMode;
  final String deviceName;
  final DateTime createdAt;

  SessionInfo({
    required this.ip,
    required this.port,
    required this.sessionId,
    required this.pin,
    String? roomCode,
    this.isInternetMode = true,
    required this.deviceName,
    DateTime? createdAt,
  })  : roomCode = roomCode ?? pin,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'ip': ip,
      'port': port,
      'sessionId': sessionId,
      'pin': pin,
      'roomCode': roomCode,
      'isInternetMode': isInternetMode,
      'deviceName': deviceName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SessionInfo.fromMap(Map<String, dynamic> map) {
    return SessionInfo(
      ip: map['ip'] as String? ?? '',
      port: map['port'] as int? ?? 8888,
      sessionId: map['sessionId'] as String? ?? '',
      pin: map['pin'] as String? ?? '',
      roomCode: (map['roomCode'] ?? map['pin']) as String? ?? '',
      isInternetMode: map['isInternetMode'] as bool? ?? true,
      deviceName: map['deviceName'] as String? ?? 'Android Device',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SessionInfo.fromJson(String source) =>
      SessionInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
