import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart';
import 'package:flutter/foundation.dart'; // 🌟 加上这一行来支持 debugPrint

class EmbyService {
  /// 1. 🌟 全新升级：直接调用 Emby 官方 API 刷新媒体库（彻底抛弃虚假的私有 API）
  static Future<bool> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 直接读取咱们在设置里填好的真实 Emby 地址
      final embyUrl = prefs.getString('emby_url')?.replaceAll(RegExp(r'/$'), '');
      final apiKey = prefs.getString('emby_api_key');

      if (embyUrl == null || embyUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
        debugPrint("❌ Emby 未配置，跳过刷新");
        return false;
      }

      debugPrint("🔄 正在直接命令 Emby 刷新媒体库...");
      
      // 🌟 核心：直接调用 Emby 官方的全量刷新接口！
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

  /// 2. 🌟 超级模糊路径匹配：无视刮削名称，只要物理路径对得上就秒播！
  static Future<String?> findItemIdByPath(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 🌟 清理了误导的默认网址和 Token，强制使用用户自己的配置
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

      // 2. 先尝试用 SearchTerm 精准搜索
      final url = "$embyUrl/emby/Items?SearchTerm=${Uri.encodeComponent(title)}&Recursive=true&IncludeItemTypes=Movie&Fields=Path&api_key=$apiKey";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List items = data['Items'] ?? [];

        // 🌟 兜底机制：如果 SearchTerm 没搜到（比如番号搜不到），直接拉取最近50个项目
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

          // 方案B：名字包含特征词 
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