import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';

class EmbyService {
  /// 触发后端进行硬链接整理并刷新 Emby 库
  static Future<void> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 🌟 读取你刚才在 NPM 里配置的 API 域名
      final apiUrl = prefs.getString('orbix_api_url') ?? 'https://api.dmitt.com/api/sync';
      
      // 🌟 必须与你服务器 app.py 里的 SECRET_TOKEN 保持一致
      final apiToken = prefs.getString('orbix_api_token') ?? 'orbix_super_secret_token_2026';

      // 1. 在本地先清洗文件名，生成标准的 "电影名称 (年份)"
      final parsed = Utils.cleanFileName(torrentName);
      final cleanName = "${parsed['title']} (${parsed['year']})";

      Utils.showToast("🚀 正在请求中枢整理资源...");

      // 2. 发送 POST 请求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": apiToken,
          "torrent_name": torrentName,
          "target_name": cleanName, // 传过去直接让后端按这个名字建文件夹
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        Utils.showToast("✅ 整理成功：${result['message']}");
      } else {
        Utils.showToast("❌ 整理失败：${result['message'] ?? '服务器响应异常'}");
      }
    } catch (e) {
      print("❌ OrbiX API 请求异常: $e");
      Utils.showToast("❌ 无法连接到指挥中枢");
    }
  }
}