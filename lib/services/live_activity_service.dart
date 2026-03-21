import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../core/utils.dart';

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');
  static Timer? _timer;

  static Future<void> start(String movieName) async {
    try {
      final result = await _channel.invokeMethod('startDownload', {'movieName': movieName});
      if (result == true) {
        _startTracking();
      }
    } on PlatformException catch (e) {
      Utils.showToast("灵动岛报错: ${e.message}");
      debugPrint("灵动岛点火失败: ${e.message}");
    } catch (e) {
      Utils.showToast("灵动岛启动异常");
      debugPrint("灵动岛启动异常: $e");
    }
  }

  static Future<void> update(double progress, String speed, String eta, String sizeInfo) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'progress': progress,
        'speed': speed,
        'eta': eta,
        'sizeInfo': sizeInfo, // 🚀 推送文件大小信息
      });
    } catch (e) {
      debugPrint("灵动岛更新失败: $e");
    }
  }

  static Future<void> stop() async {
    try {
      _timer?.cancel();
      await _channel.invokeMethod('stopDownload');
    } catch (e) {
      debugPrint("灵动岛收起失败: $e");
    }
  }

  static void _startTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final torrents = await ApiService.getTorrents(filter: 'downloading');
        
        if (torrents == null || torrents.isEmpty) {
          stop();
          return;
        }

        torrents.sort((a, b) => (b['dlspeed'] ?? 0).compareTo(a['dlspeed'] ?? 0));
        final activeTask = torrents.first;

        double progress = (activeTask['progress'] ?? 0).toDouble();
        int speedRaw = activeTask['dlspeed'] ?? 0;
        String speedStr = "${Utils.formatBytes(speedRaw)}/s";
        
        // 🚀 新增：解析大小信息
        int completed = activeTask['completed'] ?? 0;
        int totalSize = activeTask['size'] ?? 0;
        String sizeInfo = "${Utils.formatBytes(completed)} / ${Utils.formatBytes(totalSize)}";
        
        // 🚀 升级：更智能的 ETA 算法
        int etaRaw = activeTask['eta'] ?? 8640000;
        String etaStr;
        
        if (speedRaw == 0) {
          etaStr = "等待速度..."; // 没有速度的时候显示等待，避免显示 8640000
        } else if (etaRaw >= 8640000 || etaRaw < 0) {
          etaStr = "计算中...";
        } else {
          int hours = etaRaw ~/ 3600;
          int minutes = (etaRaw % 3600) ~/ 60;
          int seconds = etaRaw % 60;
          
          if (hours > 0) {
             // 超过一小时，显示 h 和 m，避免文字过长挤破 UI
            etaStr = "剩余 ${hours}h ${minutes}m";
          } else {
            etaStr = "剩余 ${minutes}m ${seconds}s";
          }
        }

        update(progress, speedStr, etaStr, sizeInfo);

        if (progress >= 1.0) {
          stop();
        }
      } catch (e) {
        debugPrint("轮询网速异常: $e");
      }
    });
  }
}