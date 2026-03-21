import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');

  static Future<void> start(String movieName) async {
    try {
      await _channel.invokeMethod('startDownload', {'movieName': movieName});
    } catch (e) {
      debugPrint("灵动岛点火失败: $e");
    }
  }

  static Future<void> update(double progress, String speed) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'progress': progress,
        'speed': speed,
      });
    } catch (e) {
      debugPrint("灵动岛更新失败: $e");
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopDownload');
    } catch (e) {
      debugPrint("灵动岛收起失败: $e");
    }
  }
}