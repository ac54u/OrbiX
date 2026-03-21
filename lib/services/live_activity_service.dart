import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LiveActivityService {
  // 定义专属通道名称，必须与 iOS 端保持完全一致
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');

  /// 1. 🚀 点火开岛
  static Future<void> start(String movieName) async {
    try {
      await _channel.invokeMethod('startDownload', {'movieName': movieName});
      debugPrint("Flutter: 灵动岛已点火");
    } catch (e) {
      debugPrint("Flutter 点火失败: $e");
    }
  }

  /// 2. ⚡️ 实时更新进度与网速
  static Future<void> update(double progress, String speed) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'progress': progress,
        'speed': speed,
      });
    } catch (e) {
      debugPrint("Flutter 更新失败: $e");
    }
  }

  /// 3. 🛑 功德圆满：结束并收起灵动岛
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopDownload');
      debugPrint("Flutter: 灵动岛已收起");
    } catch (e) {
      debugPrint("Flutter 收起失败: $e");
    }
  }
}