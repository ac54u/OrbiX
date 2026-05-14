import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../core/network/dio_client.dart';

class MeTubeService {
  static final Dio _dio = DioClient.create();

  // 默认直接使用你的服务器地址
  static const String defaultUrl = 'http://152.53.131.108:5551';

  /// 提交链接给 MeTube 下载
  static Future<String?> addDownloadTask(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metubeUrl = prefs.getString('metube_url') ?? defaultUrl;

      final r = await _dio.post(
        '$metubeUrl/add',
        data: {'url': url, 'quality': 'best', 'format': 'any'},
        options: Options(validateStatus: (status) => true),
      );

      if (r.statusCode == 200 && r.data['status'] == 'ok') {
        return null; // 成功
      } else {
        return "MeTube 拒绝了请求: ${r.data}";
      }
    } catch (e) {
      return "无法连接到 MeTube，请检查网络或地址配置。";
    }
  }

  /// 获取 MeTube 的当前队列和历史记录
  static Future<List<dynamic>> getDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metubeUrl = prefs.getString('metube_url') ?? defaultUrl;

      final r = await _dio.get('$metubeUrl/api/v1/history');

      if (r.statusCode == 200) {
        List<dynamic> allTasks = [];
        // MeTube 返回的数据通常包含 queue 和 history 两个列表
        if (r.data['queue'] != null) {
          allTasks.addAll(r.data['queue']);
        }
        if (r.data['history'] != null) {
          allTasks.addAll(r.data['history']);
        }
        return allTasks;
      }
      return [];
    } catch (e) {
      debugPrint("获取 MeTube 状态失败: $e");
      return [];
    }
  }
}