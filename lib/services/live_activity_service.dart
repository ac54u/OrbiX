import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../core/utils.dart'; // 确保引入了 Utils

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');
  static Timer? _timer;
  static bool _isActive = false; 
  static final _LifecycleObserver _observer = _LifecycleObserver();

  /// 1. 🚀 点亮灵动岛并开始监听网速
  static Future<void> start(String movieName) async {
    try {
      final result = await _channel.invokeMethod('startDownload', {'movieName': movieName});
      if (result == true) {
        _isActive = true;
        _startTracking(); 
        
        WidgetsBinding.instance.removeObserver(_observer);
        WidgetsBinding.instance.addObserver(_observer);
      }
    } on PlatformException catch (e) {
      Utils.showToast("灵动岛报错: ${e.message}");
      debugPrint("灵动岛点火失败: ${e.message}");
    } catch (e) {
      Utils.showToast("灵动岛启动异常");
      debugPrint("灵动岛启动异常: $e");
    }
  }

  /// 2. ⚡️ 向原生发送最新数据
  static Future<void> update(double progress, String speed, String eta, String sizeInfo) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'progress': progress,
        'speed': speed,
        'eta': eta,
        'sizeInfo': sizeInfo,
      });
    } catch (e) {
      debugPrint("灵动岛更新失败: $e");
    }
  }

  /// 3. 🛑 结束并收起灵动岛
  static Future<void> stop() async {
    try {
      _isActive = false;
      _timer?.cancel(); 
      WidgetsBinding.instance.removeObserver(_observer); 
      await _channel.invokeMethod('stopDownload');
    } catch (e) {
      debugPrint("灵动岛收起失败: $e");
    }
  }

  /// 🔄 内部定时器
  static void _startTracking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _fetchAndUpdate();
    });
  }

  /// 🔌 拉取数据并更新状态
  static Future<void> _fetchAndUpdate() async {
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
      
      int completed = activeTask['completed'] ?? 0;
      int totalSize = activeTask['size'] ?? 0;
      String sizeInfo = "${Utils.formatBytes(completed)} / ${Utils.formatBytes(totalSize)}";
      
      int etaRaw = activeTask['eta'] ?? 8640000;
      String etaStr;
      
      if (speedRaw == 0) {
        etaStr = "等待速度...";
      } else if (etaRaw >= 8640000 || etaRaw < 0) {
        etaStr = "计算中...";
      } else {
        int hours = etaRaw ~/ 3600;
        int minutes = (etaRaw % 3600) ~/ 60;
        int seconds = etaRaw % 60;
        
        if (hours > 0) {
          etaStr = "剩余 ${hours}h ${minutes}m";
        } else {
          etaStr = "剩余 ${minutes}m ${seconds}s";
        }
      }

      update(progress, speedStr, etaStr, sizeInfo);

      // 🚀 核心逻辑：进度达到 100% 时，仅做本地 UI 提示，刮削动作由服务端完成
      if (progress >= 1.0) {
        Utils.showToast("🎉 下载完成！服务器正在通知 Emby 刮削媒体库...");
        stop();
      }
    } catch (e) {
      debugPrint("轮询网速异常: $e");
    }
  }

  /// ⏸️ App 退到后台时的处理
  static void onAppPaused() {
    if (!_isActive) return;
    _timer?.cancel();
    update(0.0, "后台挂起", "--", "请回前台查看");
  }

  /// ▶️ App 回到前台时的处理
  static void onAppResumed() {
    if (!_isActive) return;
    _fetchAndUpdate();
    _startTracking();
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      LiveActivityService.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      LiveActivityService.onAppResumed();
    }
  }
}