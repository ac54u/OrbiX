import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';

class EmbyService {
  /// 1. 触发后端进行硬链接整理并刷新 Emby 库
  /// 🌟 核心修改：返回 Future<bool>，让前端知道是否可以开始轮询等待 Emby 扫描
  static Future<bool> processAndRefresh(String torrentName) async {
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
        Utils.showToast("✅ 整理成功，等待扫描...");
        return true; // 🌟 成功触发硬链接，允许前端开始轮询
      } else {
        Utils.showToast("❌ 整理失败：${result['message'] ?? '未知错误'}");
        return false; // 触发失败，拦截前端轮询
      }
    } catch (e) {
      Utils.showToast("❌ 无法连接到指挥中枢");
      return false; // 网络异常，拦截前端轮询
    }
  }

  /// 2. 智能搜索：通过文件路径匹配 Emby 中的项目
  /// 这样即使 Emby 自动改名为中文“飞驰人生3”，我们依然能找到它
  static Future<String?> findItemIdByPath(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embyUrl = prefs.getString('emby_url') ?? 'https://emby.dmitt.com';
      final apiKey = prefs.getString('emby_api_key') ?? 'e1610959a3d1443db6554150602fdf12';
      final cleanUrl = embyUrl.endsWith('/') ? embyUrl.substring(0, embyUrl.length - 1) : embyUrl;

      // 🌟 核心优化：降维打击，全部转为小写并去除头尾空格
      final parsed = Utils.cleanFileName(torrentName);
      final searchTitle = parsed['title'].toString().toLowerCase().trim();

      // 必须带上 Fields=Path
      final url = "$cleanUrl/emby/Items?Recursive=true&IncludeItemTypes=Movie&SortBy=DateCreated&SortOrder=Descending&Limit=50&Fields=Path&api_key=$apiKey";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['Items'] ?? [];

        for (var item in items) {
          final String path = (item['Path'] ?? '').toString().toLowerCase();

          // 只要硬盘路径包含这个小写的片名，就算命中！
          if (path.contains(searchTitle)) {
            print("🎯 超级模糊匹配成功！ID: ${item['Id']}");
            return item['Id'].toString();
          }
        }
      }
    } catch (e) {
      print("❌ Emby 路径搜索异常: $e");
    }
    return null; // 彻底没找到
  }
}