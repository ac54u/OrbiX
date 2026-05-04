import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmbyService {
  static Future<bool> refreshLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      
      final customApiBaseUrl = prefs.getString('custom_api_url') ?? '';
      
      if (customApiBaseUrl.isEmpty) {
        print("⚠️ 未配置私有微服务地址，跳过 Emby 刷新");
        return false;
      }

      final url = '$customApiBaseUrl/refresh-emby';
      
      final response = await http.post(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print("✅ 成功通过私有微服务触发 Emby 扫库！");
        return true;
      } else {
        print("❌ 通知私有微服务失败，状态码: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ 私有微服务请求异常: $e");
      return false;
    }
  }
}
