import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart'; // 使用你封装的安全网络基座

class MyTubeService {
  // 🌟 独立的 Dio 实例，专用于 MeTube 交互
  static final Dio _dio = DioClient.create();

  /// 提交 YouTube (或 B站/Twitch) 链接给服务器的 MeTube 去下载
  static Future<String?> addDownloadTask(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 动态读取配置，如果没有配，默认使用你刚刚搭建好的服务器 IP 和 5551 端口
      final mytubeUrl = prefs.getString('mytube_url') ?? 'http://152.53.131.108:5551';

      // ⚠️ MeTube 的官方 API 接口是 /add
      final endpoint = '$mytubeUrl/add';

      debugPrint("🚀 正在将任务提交给 MeTube 核心引擎: $endpoint");

      final r = await _dio.post(
        endpoint,
        data: {
          'url': url,
          'quality': 'best', // 默认拉取最高画质
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      if (r.statusCode == 200) {
        // MeTube 的特点：哪怕报错也是 200，所以必须检查 body 里的 status
        final data = r.data is String ? jsonDecode(r.data) : r.data;

        if (data != null && data['status'] == 'ok') {
          debugPrint("✅ MeTube 接收任务成功！");
          return null; // 返回 null 代表完全成功
        } else {
          String errorMsg = data['error']?.toString() ?? "未知的解析错误";
          return "MeTube 解析失败: $errorMsg";
        }
      } else {
        return "服务器响应异常: HTTP ${r.statusCode}";
      }
    } catch (e) {
      debugPrint("MeTube 连接异常: $e");
      return "无法连接到 MeTube 服务，请确认后台 Docker 是否运行正常。";
    }
  }
}