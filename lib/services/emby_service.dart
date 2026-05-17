import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';
import 'package:flutter/foundation.dart'; // 🌟 支持 debugPrint

class EmbyService {
  /// 1. 直接调用 Emby 官方 API 刷新媒体库
  static Future<bool> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final embyUrl = prefs.getString('emby_url')?.replaceAll(RegExp(r'/$'), '');
      final apiKey = prefs.getString('emby_api_key');

      if (embyUrl == null || embyUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
        debugPrint("❌ Emby 未配置，跳过刷新");
        return false;
      }

      debugPrint("🔄 正在直接命令 Emby 刷新媒体库...");
      
      final response = await http.post(
        Uri.parse("$embyUrl/emby/Library/Refresh?api_key=$apiKey"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint("✅ Emby 媒体库刷新指令发送成功");
        return true;
      }
    } catch (e) {
      debugPrint("❌ Emby 刷新请求异常: $e");
    }
    return false;
  }

  /// 2. 🌟 超级模糊路径匹配：通吃 Movie 和 Video 类型！
  static Future<String?> findItemIdByPath(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final embyUrl = prefs.getString('emby_url')?.replaceAll(RegExp(r'/$'), '');
      final apiKey = prefs.getString('emby_api_key');

      if (embyUrl == null || embyUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
        debugPrint("❌ Emby 未配置，无法检索");
        return null;
      }

      // 1. 提取核心特征码
      final parsed = Utils.cleanFileName(torrentName);
      final String title = parsed['title'].toString().toLowerCase().trim();

      debugPrint("🔍 [Radar] 正在检索: $title");

      // 🌟 核心修改：IncludeItemTypes 扩充为 Movie,Video！完美通吃番号和常规电影！
      final url = "$embyUrl/emby/Items?SearchTerm=${Uri.encodeComponent(title)}&Recursive=true&IncludeItemTypes=Movie,Video&Fields=Path&api_key=$apiKey";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List items = data['Items'] ?? [];

        // 🌟 兜底机制：IncludeItemTypes 同步扩充为 Movie,Video
        if (items.isEmpty) {
          final fallbackUrl = "$embyUrl/emby/Items?Recursive=true&IncludeItemTypes=Movie,Video&SortBy=DateCreated&SortOrder=Descending&Limit=50&Fields=Path&api_key=$apiKey";
          final fallbackResp = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 8));
          if (fallbackResp.statusCode == 200) {
            items = jsonDecode(fallbackResp.body)['Items'] ?? [];
          }
        }

        // 3. 开始遍历比对
        for (var item in items) {
          final String embyPath = (item['Path'] ?? '').toString().toLowerCase();
          final String embyName = (item['Name'] ?? '').toString().toLowerCase();

          bool pathMatch = embyPath.isNotEmpty && embyPath.contains(title);
          bool nameMatch = embyName.contains(title);
          bool cleanNameMatch = embyName.replaceAll('-', '').contains(title.replaceAll('-', ''));

          if (pathMatch || nameMatch || cleanNameMatch) {
            debugPrint("🎯 [Match Success] ID: ${item['Id']} Name: ${item['Name']}");
            return item['Id'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [Emby Error] $e");
    }
    return null;
  }
}
