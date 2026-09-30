class AppConstants {
  static const String appName = 'ViziLink Security Lab';
  static const String appVersion = '1.0.0';
  static const int defaultPort = 8888;
  static const int defaultTargetFps = 30;
  static const int defaultBitrateKbps = 2500;
  static const int chunkSize = 64 * 1024; // 64 KB per chunk for DataChannel

  // WebRTC ICE Servers (STUN & TURN for Internet, Cellular & LAN traversal)
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': ['stun:stun.l.google.com:19302']},
      {'urls': ['stun:stun1.l.google.com:19302']},
      {'urls': ['stun:stun2.l.google.com:19302']},
      {'urls': ['stun:stun3.l.google.com:19302']},
      {
        'urls': ['turn:openrelay.metered.ca:80'],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': ['turn:openrelay.metered.ca:443'],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': ['turn:openrelay.metered.ca:443?transport=tcp'],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Video resolution presets
  static const Map<String, Map<String, int>> videoPresets = {
    '720p (Recommended)': {'width': 1280, 'height': 720},
    '1080p (High Quality)': {'width': 1920, 'height': 1080},
    '540p (Low Bandwidth)': {'width': 960, 'height': 540},
  };
}
