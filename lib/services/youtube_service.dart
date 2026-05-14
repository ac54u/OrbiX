import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/utils.dart';

/// YouTube 下载服务
/// 与 Ubuntu 服务器的 Flask API 交互
class YouTubeDownloadService {
  // 🌟 修改为你的服务器地址
  static const String _baseUrl = "http://152.53.131.108:5001/api";

  // 超时时间（秒）
  static const int _timeoutSeconds = 30;

  // 🌟 可用的下载格式
  static const List<String> _availableFormats = ['best', 'mp3', '720p'];

  // 格式标签映射
  static const Map<String, String> _formatLabels = {
    'best': '📹 最高质量 (原画质)',
    'mp3': '🎵 仅音频 (MP3)',
    '720p': '🎬 720P (中等质量)',
  };

  /// 检查是否是 YouTube 链接
  static bool isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  /// 获取可用的下载格式列表
  static List<String> getAvailableFormats() {
    return _availableFormats;
  }

  /// 获取格式的中文标签
  static String getFormatLabel(String format) {
    return _formatLabels[format] ?? format;
  }

  /// 🌟 启动下载任务
  /// 返回 task_id，失败返回 null
  static Future<String?> startDownload(
    String youtubeUrl, {
    String format = 'best',
  }) async {
    try {
      // 验证 URL
      if (!isYouTubeUrl(youtubeUrl)) {
        Utils.showToast('❌ 这不是一个有效的 YouTube 链接');
        return null;
      }

      // 验证格式
      if (!_availableFormats.contains(format)) {
        Utils.showToast('❌ 不支持的格式: $format');
        return null;
      }

      final url = Uri.parse('$_baseUrl/download');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'url': youtubeUrl,
              'format': format,
            }),
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      // 🔍 调试日志
      print('📡 YouTube 下载请求');
      print('URL: $youtubeUrl');
      print('Format: $format');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 202 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final taskId = data['task_id'];

        if (taskId != null) {
          print('✅ 下载任务已启动，Task ID: $taskId');
          return taskId;
        }
      }

      print('❌ 启动下载失败: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ 网络错误: $e');
      Utils.showToast('网络错误: $e');
      return null;
    }
  }

  /// 🌟 获取下载状态
  /// 返回状态信息 Map，失败返回 null
  static Future<Map<String, dynamic>?> getDownloadStatus(String taskId) async {
    try {
      final url = Uri.parse('$_baseUrl/status/$taskId');

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      // 🔍 调试日志
      print('📡 查询下载状态');
      print('Task ID: $taskId');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 获取状态成功: ${data['status']}');
        return data;
      }

      print('❌ 获取状态失败: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ 网络错误: $e');
      return null;
    }
  }

  /// 🌟 获取已下载的文件列表
  /// 返回文件列表，失败返回空列表
  static Future<List<Map<String, dynamic>>> getDownloadedFiles() async {
    try {
      final url = Uri.parse('$_baseUrl/files');

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      // 🔍 调试日志
      print('📡 获取文件列表');
      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = List<Map<String, dynamic>>.from(data['files'] ?? []);

        print('✅ 获取文件列表成功: ${files.length} 个文件');
        return files;
      }

      print('❌ 获取文件列表失败: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ 网络错误: $e');
      return [];
    }
  }

  /// 🌟 删除已下载的文件
  /// 返回是否删除成功
  static Future<bool> deleteFile(String filename) async {
    try {
      // URL 编码文件名
      final encodedFilename = Uri.encodeComponent(filename);
      final url = Uri.parse('$_baseUrl/download/$encodedFilename');

      final response = await http
          .delete(
            url,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      // 🔍 调试日志
      print('📡 删除文件');
      print('Filename: $filename');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ 文件删除成功');
        return true;
      }

      print('❌ 删除文件失败: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ 网络错误: $e');
      Utils.showToast('删除文件失败: $e');
      return false;
    }
  }

  /// 🌟 获取下载进度百分比
  /// 返回 0-100 的整数
  static Future<int> getDownloadProgress(String taskId) async {
    final status = await getDownloadStatus(taskId);
    if (status != null) {
      return (status['progress'] as int?) ?? 0;
    }
    return 0;
  }

  /// 🌟 获取下载状态字符串
  static Future<String> getDownloadStatusString(String taskId) async {
    final status = await getDownloadStatus(taskId);
    if (status != null) {
      return (status['status'] as String?) ?? 'unknown';
    }
    return 'unknown';
  }

  /// 🌟 获取下载的文件信息
  static Future<Map<String, dynamic>?> getDownloadedFileInfo(
    String taskId,
  ) async {
    final status = await getDownloadStatus(taskId);
    if (status != null && status['status'] == 'completed') {
      return {
        'filename': status['filename'],
        'title': status['title'],
        'duration': status['duration'],
        'completed_at': status['completed_at'],
      };
    }
    return null;
  }

  /// 🌟 轮询直到下载完成
  /// maxAttempts: 最大尝试次数（每次间隔2秒）
  /// 返回是否成功完成
  static Future<bool> pollUntilComplete(
    String taskId, {
    int maxAttempts = 300,
    Duration pollInterval = const Duration(seconds: 2),
    Function(Map<String, dynamic>)? onStatusChanged,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      final status = await getDownloadStatus(taskId);

      if (status != null) {
        // 状态改变回调
        onStatusChanged?.call(status);

        final statusStr = status['status'] ?? '';

        if (statusStr == 'completed') {
          print('✅ 下载完成');
          return true;
        } else if (statusStr == 'failed') {
          print('❌ 下载失败: ${status['error']}');
          return false;
        }

        print('⏳ 下载中... 进度: ${status['progress']}%');
      }

      // 等待后再轮询
      await Future.delayed(pollInterval);
    }

    print('❌ 轮询超时 (${maxAttempts * pollInterval.inSeconds}秒)');
    return false;
  }

  /// 🌟 健康检查（测试服务器连接）
  static Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/health');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ 服务器连接正常: ${data['status']}');
        return true;
      }

      print('❌ 服务器响应异常: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ 服务器连接失败: $e');
      return false;
    }
  }

  /// 🌟 获取服务器信息
  static Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      final url = Uri.parse('$_baseUrl/health');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('❌ 获取服务器信息失败: $e');
      return null;
    }
  }

  /// 🌟 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 🌟 解析下载状态字符串
  static String getStatusLabel(String status) {
    switch (status) {
      case 'processing':
        return '⏳ 处理中...';
      case 'downloading':
        return '📥 下载中...';
      case 'completed':
        return '✅ 已完成';
      case 'failed':
        return '❌ 失败';
      default:
        return '❓ 未知状态';
    }
  }
}
