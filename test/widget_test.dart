import 'package:flutter_test/flutter_test.dart';
import 'package:mirroro/models/file_transfer_model.dart';
import 'package:mirroro/models/session_info.dart';
import 'package:mirroro/models/stream_stats.dart';

void main() {
  group('ViziLink Security Lab Model & Logic Tests', () {
    test('SessionInfo serialization and deserialization', () {
      final original = SessionInfo(
        ip: '192.168.1.50',
        port: 8888,
        sessionId: 'test-session-1234',
        pin: '948201',
        deviceName: 'Phone A Test',
      );

      final json = original.toJson();
      final reconstructed = SessionInfo.fromJson(json);

      expect(reconstructed.ip, '192.168.1.50');
      expect(reconstructed.port, 8888);
      expect(reconstructed.sessionId, 'test-session-1234');
      expect(reconstructed.pin, '948201');
      expect(reconstructed.deviceName, 'Phone A Test');
    });

    test('FileTransferItem progress and chunk calculations', () {
      final item = FileTransferItem(
        id: 'file-001',
        name: 'capture.mp4',
        totalBytes: 1000,
        totalChunks: 10,
        sha256Expected: 'abcdef123456',
        isOutgoing: true,
        bytesTransferred: 500,
      );

      expect(item.progress, 0.5);
      expect(item.isCompleted, false);

      item.bytesTransferred = 1000;
      item.status = FileTransferStatus.completed;
      expect(item.progress, 1.0);
      expect(item.isCompleted, true);
    });

    test('StreamStats defaults and copyWith', () {
      final initial = StreamStats.initial();
      expect(initial.fps, 0.0);
      expect(initial.latencyMs, 0);

      final updated = initial.copyWith(
        fps: 30.0,
        latencyMs: 50,
        bitrateKbps: 2450.0,
      );

      expect(updated.fps, 30.0);
      expect(updated.latencyMs, 50);
      expect(updated.bitrateKbps, 2450.0);
    });
  });
}
