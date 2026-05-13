import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';

class EmbyService {
  /// 1. 触发后端进行硬链接整理并刷新 Emby 库
  static Future<void> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiUrl = prefs.getString('orbix_api_url') ?? 'https://api.dmitt.com/api/sync';
      final apiToken = prefs.getString('orbix_api_token') ?? 'orbix_super_secret_token_2026';

      final parsed = Utils.cleanFileName(torrentName);
      final cleanName = "${parsed['title']} (${parsed['year']})";

      Utils.showToast("🚀 正在请求中枢整理资源...");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": apiToken,
          "torrent_name": torrentName,
          "target_name": cleanName,
        }),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        Utils.showToast("✅ 整理成功：${result['message']}");
      } else {
        Utils.showToast("❌ 整理失败：${result['message'] ?? '服务器响应异常'}");
      }
    } catch (e) {
      Utils.showToast("❌ 无法连接到指挥中枢");
    }
  }

  /// 2. 智能搜索：通过文件路径匹配 Emby 中的项目
  /// 这样即使 Emby 自动改名为中文“飞驰人生3”，我们依然能找到它
  static Future<String?> findItemIdByPath(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embyUrl = prefs.getString('emby_url') ?? 'https://emby.dmitt.com';
      final apiKey = prefs.getString('emby_api_key') ?? 'e1610959a3d1443db6554150602fdf12';

      // 获取清洗后的标准名称，例如 "Pegasus 3 (2026)"
      final parsed = Utils.cleanFileName(torrentName);
      final cleanName = "${parsed['title']} (${parsed['year']})";

      // 请求 Emby 最近添加的 50 个项目，并要求返回 Path 字段
      final url = "$embyUrl/Items?Recursive=true&IncludeItemTypes=Movie&SortBy=DateCreated&SortOrder=Descending&Limit=50&Fields=Path&api_key=$apiKey";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['Items'] ?? [];

        for (var item in items) {
          final String path = item['Path'] ?? '';
          // 🌟 核心匹配逻辑：检查物理路径是否包含我们的清洗名
          if (path.contains(cleanName)) {
            print("🎯 匹配成功！刮削标题: ${item['Name']}, ID: ${item['Id']}");
            return item['Id'].toString();
          }
        }
      }
    } catch (e) {
      print("❌ Emby 搜索异常: $e");
    }
    return null; // 没找到
  }
}