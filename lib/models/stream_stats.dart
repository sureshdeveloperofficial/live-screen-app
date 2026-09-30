class StreamStats {
  final double fps;
  final int latencyMs;
  final double bitrateKbps;
  final int packetsLost;
  final String resolution;
  final String connectionType;
  final DateTime timestamp;

  const StreamStats({
    this.fps = 0.0,
    this.latencyMs = 0,
    this.bitrateKbps = 0.0,
    this.packetsLost = 0,
    this.resolution = 'Unknown',
    this.connectionType = 'Wi-Fi',
    required this.timestamp,
  });

  factory StreamStats.initial() {
    return StreamStats(
      fps: 0,
      latencyMs: 0,
      bitrateKbps: 0,
      packetsLost: 0,
      resolution: '720p',
      connectionType: 'Wi-Fi',
      timestamp: DateTime.now(),
    );
  }

  StreamStats copyWith({
    double? fps,
    int? latencyMs,
    double? bitrateKbps,
    int? packetsLost,
    String? resolution,
    String? connectionType,
    DateTime? timestamp,
  }) {
    return StreamStats(
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      packetsLost: packetsLost ?? this.packetsLost,
      resolution: resolution ?? this.resolution,
      connectionType: connectionType ?? this.connectionType,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
