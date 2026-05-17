import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class YouTubeDownloadService {
  // 🌟 必须匹配你 FastAPI 的 9000 端口和服务器 IP
  static const String baseUrl = 'http://152.53.131.108:9000';

  // 识别是否为 YouTube 链接
  static bool isYouTubeUrl(String url) {
    return url.contains('youtube.com/') || url.contains('youtu.be/');
  }

  // 1. 发起下载任务 (🌟 升级：无参数干扰，强制后端拉取 'best' 最高画质)
  static Future<String?> startDownload(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/download'),
        headers: {'Content-Type': 'application/json'},
        // 直接在 body 里写死 format: 'best'
        body: jsonEncode({'url': url, 'format': 'best'}), 
      );
      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['task_id'];
      }
    } catch (e) {
      print('Start YouTube Download Error: $e');
    }
    return null;
  }

  // 2. 轮询直到完成 (用于页面等待/进度刷新逻辑)
  static Future<bool> pollUntilComplete(
    String taskId, {
    int maxAttempts = 600,
    Function(Map<String, dynamic>)? onStatusChanged,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      final statusData = await getTaskStatus(taskId);
      if (statusData != null) {
        if (onStatusChanged != null) onStatusChanged(statusData);
        
        final status = statusData['status'];
        if (status == 'completed') return true;
        if (status == 'failed') return false;
      }
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
    }
    return false;
  }

  // 3. 单次获取状态
  static Future<Map<String, dynamic>?> getTaskStatus(String taskId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status/$taskId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('Get Status Error: $e');
    }
    return null;
  }

  // 4. 获取已完成的文件列表
  static Future<List<dynamic>> getFiles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/files'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['files'] ?? [];
      }
    } catch (e) {
      print('Get Files Error: $e');
    }
    return [];
  }

  // 5. 删除文件
  static Future<bool> deleteFile(String filename) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/download/${Uri.encodeComponent(filename)}'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 6. 获取播放直链
  static String getVideoUrl(String path) {
    return '$baseUrl$path';
  }
}