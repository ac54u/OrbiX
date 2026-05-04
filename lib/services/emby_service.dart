import 'dart:convert'; // 引入 json
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmbyService {
  // 传入刚刚下载完成的任务名字
  static Future<bool> processAndRefresh(String torrentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customApiBaseUrl = prefs.getString('custom_api_url') ?? '';
      
      if (customApiBaseUrl.isEmpty) return false;

      // 🚀 调用我们新写的自动化接口
      final url = '$customApiBaseUrl/torrent-completed';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        // 把任务名字作为 JSON 传过去
        body: jsonEncode({"torrent_name": torrentName}),
      ).timeout(const Duration(seconds: 10)); // 稍微延长超时，因为硬盘可能有 IO 延迟
      
      if (response.statusCode == 200) {
        print("✅ 自动化处理成功: ${response.body}");
        return true;
      } else {
        print("❌ 自动化处理失败: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ 私有微服务请求异常: $e");
      return false;
    }
  }
}
