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

/// 获取 MeTube 的当前队列和历史记录（精准字段匹配版）
  static Future<List<dynamic>> getDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String metubeUrl = prefs.getString('metube_url') ?? defaultUrl;
      if (metubeUrl.endsWith('/')) {
        metubeUrl = metubeUrl.substring(0, metubeUrl.length - 1);
      }

      final r = await _dio.get('$metubeUrl/history');

      if (r.statusCode == 200) {
        List<dynamic> allTasks = [];

        if (r.data is Map) {
          // 🌟 致命修复：已完成的字段名是 'done'，不是 'history'
          if (r.data['queue'] != null) allTasks.addAll(r.data['queue']);
          if (r.data['done'] != null) allTasks.addAll(r.data['done']);
          if (r.data['pending'] != null) allTasks.addAll(r.data['pending']);
        } else if (r.data is List) {
          allTasks.addAll(r.data);
        }

        return allTasks;
      }
      return [];
    } catch (e) {
      debugPrint("🚨 请求 MeTube 彻底失败: $e");
      return [];
    }
  }
}