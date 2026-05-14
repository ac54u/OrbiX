import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ==========================================
// 🌟 全新的专属 MeTube API 服务
// ==========================================
class MyTubeService {
  // 你的专属 MeTube 服务器地址
  static const String baseUrl = "http://152.53.131.108:5551";

  // 如果你之前封装了 DioClient，这里可以换成 DioClient.create()
  static final Dio _dio = Dio();

  /// 提交下载任务到 MeTube
  /// 返回 null 表示成功，返回 String 表示错误信息
  static Future<String?> addDownloadTask(String url) async {
    try {
      final response = await _dio.post(
        "$baseUrl/add",
        data: {
          "url": url,
          "quality": "best" // 默认最高画质
        },
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        // Dio 自动将响应体解析为 Map
        final data = response.data is String ? jsonDecode(response.data) : response.data;

        // MeTube 添加成功通常返回 {"status": "ok"}
        if (data != null && data['status'] == 'ok') {
          return null; // 成功
        } else {
          return data['error']?.toString() ?? "MeTube 返回未知错误";
        }
      } else {
        return "服务器响应异常，状态码: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("MeTube 请求失败: $e");
      return "无法连接到 MeTube，请检查服务器或网络状态";
    }
  }

  /// 🌟 新增：获取 MeTube 的下载记录
  static Future<List<dynamic>> getTasks() async {
    try {
      // 请求 MeTube 的历史记录接口
      final response = await _dio.get(
        "$baseUrl/api/v1/history",
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;

        // 转换数据格式，以便完美兼容你现有的 qBittorrent 列表 UI
        return data.map((item) => {
          'hash': item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // 用 ID 充当 Hash
          'name': item['title'] ?? 'YouTube 视频',
          'progress': 1.0, // 历史记录里的都是 100% 完成的
          'state': 'completed',
          'size': item['file_size'] ?? 0,
          'is_yt': true, // 核心标记：告诉 UI 这是 YouTube 任务
          'poster': '', // MeTube 历史记录不带封面，直接留空
        }).toList();
      }
    } catch (e) {
      debugPrint("获取 MeTube 历史失败: $e");
    }
    return [];
  }
}