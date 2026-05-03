import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  // ⚠️ 替换为你自己的 TMDB API Key
  static const String _apiKey = '6bb9132f55e93fea1712364280a7919a; 
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/';

  static Future<Map<String, dynamic>?> searchMovie(String title, String? year) async {
    if (_apiKey == 'YOUR_TMDB_API_KEY_HERE') {
      print("⚠️ 请先在 tmdb_service.dart 中配置 API Key");
      return null;
    }

    try {
      String url = '$_baseUrl/search/movie?api_key=$_apiKey&language=zh-CN&query=${Uri.encodeComponent(title)}';
      if (year != null && year.isNotEmpty) {
        url += '&year=$year';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final movie = data['results'][0]; // 取最佳匹配项
          
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
      return null;
    } catch (e) {
      print("TMDB 请求异常: $e");
      return null;
    }
  }
}