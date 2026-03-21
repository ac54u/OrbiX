import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../core/utils.dart'; // 确保引入了 Utils

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');
  static Timer? _timer;

  /// 1. 🚀 点亮灵动岛并开始监听网速
  static Future<void> start(String movieName) async {
    try {
      final result = await _channel.invokeMethod('startDownload', {'movieName': movieName});
      if (result == true) {
        _startTracking(); // 启动后台轮询
      }
    } on PlatformException catch (e) {
      Utils.showToast("灵动岛报错: ${e.message}");
      debugPrint("灵动岛点火失败: ${e.message}");
    } catch (e) {
      Utils.showToast("灵动岛启动异常");
      debugPrint("灵动岛启动异常: $e");
    }
  }

  /// 2. ⚡️ 向原生发送最新数据 (增加 eta 参数)
  static Future<void> update(double progress, String speed, String eta) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'progress': progress,
        'speed': speed,
        'eta': eta, // 🚀 发送剩余时间
      });
    } catch (e) {
      debugPrint("灵动岛更新失败: $e");
    }
  }

  /// 3. 🛑 结束并收起灵动岛
  static Future<void> stop() async {
    try {
      _timer?.cancel(); // 停止轮询
      await _channel.invokeMethod('stopDownload');
    } catch (e) {
      debugPrint("灵动岛收起失败: $e");
    }
  }

  /// 🔄 内部定时器：每 2 秒去 qBittorrent 查一次进度
  static void _startTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        // 获取当前正在下载的任务
        final torrents = await ApiService.getTorrents(filter: 'downloading');
        
        if (torrents == null || torrents.isEmpty) {
          stop();
          return;
        }

        // 取下载速度最快的一个任务
        torrents.sort((a, b) => (b['dlspeed'] ?? 0).compareTo(a['dlspeed'] ?? 0));
        final activeTask = torrents.first;

        // 计算进度和网速
        double progress = (activeTask['progress'] ?? 0).toDouble();
        String speedStr = "${Utils.formatBytes(activeTask['dlspeed'] ?? 0)}/s";
        
        // 🚀 核心升级：解析 qBittorrent 返回的 ETA (剩余时间秒数)
        int etaRaw = activeTask['eta'] ?? 8640000;
        String etaStr;
        if (etaRaw >= 8640000 || etaRaw < 0) {
          etaStr = "计算中...";
        } else {
          // 格式化为：剩余 X分Y秒
          int minutes = etaRaw ~/ 60;
          int seconds = etaRaw % 60;
          etaStr = "剩余 $minutes分$seconds秒";
        }

        // 把进度、网速、剩余时间一起推给 iOS 原生
        update(progress, speedStr, etaStr);

        // 如果进度达到 100%，结束
        if (progress >= 1.0) {
          stop();
        }
      } catch (e) {
        debugPrint("轮询网速异常: $e");
      }
    });
  }
}