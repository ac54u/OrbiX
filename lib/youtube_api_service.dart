import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeApiService {
  // 🌟 核心修改：端口改为 FastAPI 的 9000
  static const String baseUrl = 'http://152.53.131.108:9000';

  // 1. 发起下载任务
  static Future<String?> startDownload(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url, 'format': 'best'}),
      );
      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['task_id']; // 返回后端生成的 UUID
      }
    } catch (e) {
      print('Start download error: $e');
    }
    return null;
  }

  // 2. 轮询获取下载进度状态
  static Future<Map<String, dynamic>?> getTaskStatus(String taskId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status/$taskId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Get status error: $e');
    }
    return null;
  }

  // 3. 获取已下载的文件列表
  static Future<List<dynamic>> getFiles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/files'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['files'] ?? [];
      }
    } catch (e) {
      print('Get files error: $e');
    }
    return [];
  }

  // 4. 删除服务器上的视频
  static Future<bool> deleteFile(String filename) async {
    try {
      // 这里的接口是 /api/download/{filename}
      final response = await http.delete(
          Uri.parse('$baseUrl/api/download/${Uri.encodeComponent(filename)}'));
      return response.statusCode == 200;
    } catch (e) {
      print('Delete file error: $e');
      return false;
    }
  }

  // 5. 拼接视频直链 (用于播放器)
  static String getVideoUrl(String path) {
    return '$baseUrl$path';
  }
}
