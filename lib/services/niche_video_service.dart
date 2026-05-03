import 'dart:convert';
import 'package:http/http.dart' as http;

class NicheVideoService {
  static Future<Map<String, dynamic>?> search(String keyword) async {
    // ⚠️ 务必把这里的 IP 换成你刚才测试成功的 VPS 的真实 IP
    final apiUrl = 'http://152.53.131.108:8000/search/$keyword'; 
    
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // 直接返回 Python 给我们的干净 JSON
        return json.decode(utf8.decode(response.bodyBytes)); 
      }
      return null;
    } catch (e) {
      print("私有 API 请求失败: $e");
      return null;
    }
  }
}