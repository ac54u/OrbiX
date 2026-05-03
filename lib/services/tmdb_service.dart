import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  static const String _apiKey = '6bb9132f55e93fea1712364280a7919a';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/';

  // 🌟 你的自定义 FastAPI 后端地址
  static const String _customApiBaseUrl = 'http://152.53.131.108:8000';

  static Future<Map<String, dynamic>?> searchMovie(String title, String? year) async {
    // 1. 判断是否是番号格式 (例如 START-518, 892OERO-002)
    final javRegex = RegExp(r'^[a-zA-Z0-9]+[-]?\d+');
    final isJav = javRegex.hasMatch(title);

    if (isJav) {
      print("识别为番号 $title，优先走自定义 API...");
      final javResult = await _fetchFromCustomApi(title);
      if (javResult != null) return javResult;
    }

    // 2. 常规电影走 TMDB
    try {
      String url = '$_baseUrl/search/movie?api_key=$_apiKey&language=zh-CN&query=${Uri.encodeComponent(title)}';
      if (year != null && year.isNotEmpty) {
        url += '&year=$year';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final movie = data['results'][0];
          return {
            'title': movie['title'] ?? movie['original_title'],
            'overview': movie['overview']?.isNotEmpty == true ? movie['overview'] : '暂无中文简介。',
            'vote_average': (movie['vote_average'] ?? 0.0).toDouble(),
            'release_date': movie['release_date'] ?? '',
            'poster_url': movie['poster_path'] != null ? '$_imageBaseUrl/w500${movie['poster_path']}' : '',
            'backdrop_url': movie['backdrop_path'] != null ? '$_imageBaseUrl/w780${movie['backdrop_path']}' : '',
          };
        }
      }
    } catch (e) {
      print("TMDB 请求异常: $e");
    }

    // 3. 最后的兜底：如果 TMDB 没搜到，再试一次私有 API
    return isJav ? null : await _fetchFromCustomApi(title);
  }

  // 🌟 适配你 main.py 中的 @app.get("/search/{keyword}")
  static Future<Map<String, dynamic>?> _fetchFromCustomApi(String title) async {
    try {
      // 🚀 修正：使用路径参数而不是查询参数
      final url = '$_customApiBaseUrl/search/${Uri.encodeComponent(title)}';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // 使用 utf8.decode 防止中文乱码
        final data = json.decode(utf8.decode(response.bodyBytes)); 
        
        if (data['poster_url'] != null && data['poster_url'].isNotEmpty) {
          return {
            'title': data['title'] ?? title,
            'overview': data['overview'] ?? '该特殊资源暂无详细简介。',
            'vote_average': (data['vote_average'] ?? 0.0).toDouble(),
            'release_date': data['release_date'] ?? '',
            'poster_url': data['poster_url'], // 这里拿到的已经是反代链接了
            'backdrop_url': '',
          };
        }
      }
      return null;
    } catch (e) {
      print("自定义 API 请求异常: $e");
      return null;
    }
  }
}
