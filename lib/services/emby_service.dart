import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';
import 'package:flutter/foundation.dart'; // 🌟 加上这一行来支持 debugPrint

class EmbyService {
  /// 1. 触发后端进行硬链接整理并刷新 Emby 库
  static Future<bool> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final apiUrl = prefs.getString('orbix_api_url') ?? 'https://api.dmitt.com/api/sync';
      final apiToken = prefs.getString('orbix_api_token') ?? 'orbix_super_secret_token_2026';

      final parsed = Utils.cleanFileName(torrentName);
      final cleanName = "${parsed['title']} (${parsed['year']})";

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
        return true;
      }
    } catch (e) {
      print("❌ OrbiX API 请求异常: $e");
    }
    return false;
  }

  /// 2. 🌟 超级模糊路径匹配：无视刮削名称，只要物理路径对得上就秒播！
  static Future<String?> findItemIdByPath(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embyUrl = (prefs.getString('emby_url') ?? 'https://emby.dmitt.com').replaceAll(RegExp(r'/$'), '');
      final apiKey = prefs.getString('emby_api_key') ?? 'e1610959a3d1443db6554150602fdf12';

      // 1. 提取核心特征码
      final parsed = Utils.cleanFileName(torrentName);
      final String title = parsed['title'].toString().toLowerCase().trim();

      debugPrint("🔍 [Radar] 正在检索: $title");

      // 2. 先尝试用 SearchTerm 精准搜索
      final url = "$embyUrl/emby/Items?SearchTerm=${Uri.encodeComponent(title)}&Recursive=true&IncludeItemTypes=Movie&Fields=Path&api_key=$apiKey";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List items = data['Items'] ?? [];

        // 🌟 兜底机制：如果 SearchTerm 没搜到（比如番号搜不到），直接拉取最近50个项目（跟你截图里在浏览器做的一模一样！）
        if (items.isEmpty) {
          final fallbackUrl = "$embyUrl/emby/Items?Recursive=true&IncludeItemTypes=Movie&SortBy=DateCreated&SortOrder=Descending&Limit=50&Fields=Path&api_key=$apiKey";
          final fallbackResp = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 8));
          if (fallbackResp.statusCode == 200) {
            items = jsonDecode(fallbackResp.body)['Items'] ?? [];
          }
        }

        // 3. 开始遍历比对
        for (var item in items) {
          final String embyPath = (item['Path'] ?? '').toString().toLowerCase();
          final String embyName = (item['Name'] ?? '').toString().toLowerCase();

          // 方案A：如果 Emby 给了 Path，且包含特征词
          bool pathMatch = embyPath.isNotEmpty && embyPath.contains(title);

          // 方案B：名字包含特征词 (去掉了死板的年份限制，只要名字包含“飞驰人生3”就中)
          bool nameMatch = embyName.contains(title);

          // 方案C：专门针对日本番号 (SGKI-086 变 SGKI086 比对)
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