import 'dart:async';
import 'package:flutter/services.dart';

class NativeCaptureService {
  static const MethodChannel _channel =
      MethodChannel('com.vizilink.securitylab/screen_capture');

  static final StreamController<void> _captureStoppedController =
      StreamController<void>.broadcast();

  static Stream<void> get onCaptureStopped => _captureStoppedController.stream;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenCaptureStopped') {
        _captureStoppedController.add(null);
      }
    });
  }

  static Future<bool> startForegroundService() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('startForegroundService');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> stopForegroundService() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('stopForegroundService');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> isServiceRunning() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
