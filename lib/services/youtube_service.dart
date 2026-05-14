import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../core/utils.dart'; // 确保你的项目中存在此工具类用于显示 Toast

/// YouTube 下载服务
/// 适配部署在 Ubuntu 服务器 (152.53.131.108:9000) 上的 FastAPI 后端
class YouTubeDownloadService {
  // 🌟 已更新为你指定的服务器地址
  static const String _baseUrl = "http://152.53.131.108:9000/api";

  // 超时时间
  static const int _timeoutSeconds = 30;

  // 可用的下载格式 (虽然服务器默认下最高画质，但保留此列表以兼容 UI)
  static const List<String> _availableFormats = ['best', 'mp3', '720p'];

  // 格式标签映射
  static const Map<String, String> _formatLabels = {
    'best': '📹 最高质量 (1080P+)',
    'mp3': '🎵 仅音频 (MP3)',
    '720p': '🎬 720P (标准清晰)',
  };

  /// 检查是否是 YouTube 链接
  static bool isYouTubeUrl(String url) {
    final RegExp regExp = RegExp(
      r'^(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+$',
      caseSensitive: false,
    );
    return regExp.hasMatch(url);
  }

  /// 获取格式的中文标签
  static String getFormatLabel(String format) {
    return _formatLabels[format] ?? format;
  }

  /// 🌟 1. 启动下载任务
  /// 发送 POST 请求到 /api/download
  static Future<String?> startDownload(
    String youtubeUrl, {
    String format = 'best',
  }) async {
    try {
      if (!isYouTubeUrl(youtubeUrl)) {
        Utils.showToast('❌ 无效的 YouTube 链接');
        return null;
      }

      final url = Uri.parse('$_baseUrl/download');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': youtubeUrl,
          'format': format,
        }),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['task_id']; // 拿到服务器生成的 8 位 task_id
      } else {
        print('❌ 启动失败: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 网络错误: $e');
      return null;
    }
  }

  /// 🌟 2. 获取下载状态 (轮询用)
  /// 请求 GET /api/status/{taskId}
  static Future<Map<String, dynamic>?> getDownloadStatus(String taskId) async {
    try {
      final url = Uri.parse('$_baseUrl/status/$taskId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ 获取状态失败: $e');
      return null;
    }
  }

  /// 🌟 3. 获取已下载文件列表
  /// 请求 GET /api/files
  static Future<List<Map<String, dynamic>>> getDownloadedFiles() async {
    try {
      final url = Uri.parse('$_baseUrl/files');
      final response = await http.get(url).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['files'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ 获取文件列表失败: $e');
      return [];
    }
  }

  /// 🌟 4. 删除服务器上的文件
  /// 请求 DELETE /api/download/{filename}
  static Future<bool> deleteFile(String filename) async {
    try {
      final encodedFilename = Uri.encodeComponent(filename);
      final url = Uri.parse('$_baseUrl/download/$encodedFilename');

      final response = await http.delete(url).timeout(const Duration(seconds: _timeoutSeconds));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ 删除失败: $e');
      return false;
    }
  }

  /// 🌟 5. 自动轮询直到下载成功
  /// [onProgress] 回调用于更新 UI 上的进度条
  static Future<bool> pollUntilComplete(
    String taskId, {
    Function(int progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    int attempts = 0;
    const int maxAttempts = 150; // 最多轮询约 5 分钟

    while (attempts < maxAttempts) {
      final statusData = await getDownloadStatus(taskId);
      if (statusData != null) {
        final String status = statusData['status'];
        final int progress = statusData['progress'] ?? 0;

        onProgress?.call(progress);
        onStatusUpdate?.call(status);

        if (status == 'completed') return true;
        if (status == 'failed') {
          Utils.showToast('❌ 下载失败: ${statusData['error']}');
          return false;
        }
      }
      
      attempts++;
      await Future.delayed(const Duration(seconds: 2)); // 每2秒查询一次
    }
    return false;
  }

  /// 🌟 6. 健康检查
  static Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 辅助方法：格式化大小
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }
}
