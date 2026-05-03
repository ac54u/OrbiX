import 'dart:convert';
import 'package:http/http.dart' as http;
import 'niche_video_service.dart'; // 🌟 引入你刚刚写好的专属服务

class TMDBService {
  static const String _apiKey = '6bb9132f55e93fea1712364280a7919a';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/';

  static Future<Map<String, dynamic>?> searchMovie(String title, String? year) async {
    // 1. 判断是否是番号格式 (例如 START-518, 892OERO-002)
    final javRegex = RegExp(r'^[a-zA-Z0-9]+[-]?\d+');
    final isJav = javRegex.hasMatch(title);

    if (isJav) {
      print("识别为番号 $title，优先走 NicheVideoService...");
      // 🚀 直接调用你的专属服务
      final javResult = await NicheVideoService.search(title);
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

    // 3. 最后的兜底：如果 TMDB 没搜到，且之前没搜过私有 API，再试一次
    return isJav ? null : await NicheVideoService.search(title);
  }
}
