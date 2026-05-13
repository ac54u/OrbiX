import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';

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
      final embyUrl = prefs.getString('emby_url') ?? 'https://emby.dmitt.com';
      final apiKey = prefs.getString('emby_api_key') ?? 'e1610959a3d1443db6554150602fdf12';

      // 去掉网址末尾可能多出的斜杠
      final cleanUrl = embyUrl.endsWith('/') ? embyUrl.substring(0, embyUrl.length - 1) : embyUrl;

      // 🎯 核心大招：只提取标题，比如把 "Pegasus 3 2026 1080p..." 变成 "pegasus 3"
      final parsed = Utils.cleanFileName(torrentName);
      final searchTitle = parsed['title'].toString().toLowerCase().trim();

      print("🔍 [OrbiX 雷达] 正在扫描路径关键词: '$searchTitle'");

      // 请求 Emby 最近添加的 50 个项目，⚠️ 必须带上 Fields=Path 才能拿到真实物理路径
      final url = "$cleanUrl/emby/Items?Recursive=true&IncludeItemTypes=Movie&SortBy=DateCreated&SortOrder=Descending&Limit=50&Fields=Path&api_key=$apiKey";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['Items'] ?? [];

        for (var item in items) {
          // 拿到物理路径并全部转成小写，比如 "/data/movies/pegasus 3 (2026)/..."
          final String path = (item['Path'] ?? '').toString().toLowerCase();

          // 如果路径中包含我们的纯净小写关键词，直接锁定目标！
          if (path.contains(searchTitle)) {
            print("🎯 [神级匹配成功] Emby ID: ${item['Id']} 实际路径: ${item['Path']}");
            return item['Id'].toString();
          }
        }
      }
    } catch (e) {
      print("❌ Emby 路径搜索异常: $e");
    }
    return null; // 如果循环完还没找到，才是真的没入库
  }
}