import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../core/utils.dart'; // 确保引入了 Utils

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.orbix/live_activity');
  static Timer? _timer;
  static bool _isActive = false; 
  static double _lastProgress = 0.0; // 🚀 用来记住退到后台前的最后进度
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
      // 获取下载中的任务
      final torrents = await ApiService.getTorrents(filter: 'downloading');
      
      if (torrents == null || torrents.isEmpty) {
        stop();
        return;
      }

      torrents.sort((a, b) => (b['dlspeed'] ?? 0).compareTo(a['dlspeed'] ?? 0));
      final activeTask = torrents.first;

      // ⚠️ 获取原始进度和状态
      double rawProgress = (activeTask['progress'] ?? 0).toDouble();
      String rawState = (activeTask['state'] ?? 'unknown').toLowerCase();

      // 🔒 核心修复：双重保险防止虚假 100%
      // 只有进度满 1.0，且状态包含 completed(完成) 或 up(做种: uploading/stalledUP) 时，才是真完成
      bool isTrulyCompleted = rawProgress >= 1.0 && 
          (rawState.contains('completed') || rawState.contains('up'));

      // 如果不是真完成，哪怕 API 瞬间抽风传回 1.0，也强行压制在 0.99，绝不让 iOS 触发完成 UI
      double safeProgress = isTrulyCompleted ? 1.0 : (rawProgress >= 1.0 ? 0.99 : rawProgress);
      
      _lastProgress = safeProgress; // 记住安全进度

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

      // 👉 将过滤后的“安全进度”传给 iOS 灵动岛
      update(safeProgress, speedStr, etaStr, sizeInfo);

      // 🚀 只有真正完成后，才吐司并停止追踪
      if (isTrulyCompleted) {
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
    
    // 传入 _lastProgress 保持进度条原样
    update(_lastProgress, "后台", "--", "请回前台查看");
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
