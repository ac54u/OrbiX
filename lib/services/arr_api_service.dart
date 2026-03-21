import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// 🚀 1. 扩充了数据模型，加入大量影视资讯参数
class MediaItem {
  final String title;
  final DateTime date;
  final String type; 
  final String posterUrl;
  final String status;
  final String overview; // 剧情简介
  final int runtime;     // 时长（分钟）
  final String network;  // 出品方或电视网

  MediaItem({
    required this.title,
    required this.date,
    required this.type,
    required this.posterUrl,
    required this.status,
    this.overview = '',
    this.runtime = 0,
    this.network = '',
  });
}

class ArrApiService {
  
  // 🚀 辅助方法：完美修复海报 URL 的拼接逻辑
  static String _buildImageUrl(String rawUrl, String baseUrl, String apiKey) {
    if (rawUrl.isEmpty) return '';
    String fullUrl = rawUrl.startsWith('http') ? rawUrl : '$baseUrl$rawUrl';
    if (!fullUrl.contains('apikey=')) {
      fullUrl += fullUrl.contains('?') ? '&apikey=$apiKey' : '?apikey=$apiKey';
    }
    return fullUrl;
  }

  static Future<List<MediaItem>> getUpcomingCalendar() async {
    List<MediaItem> allItems = [];
    
    final prefs = await SharedPreferences.getInstance();
    final String radarrUrl = prefs.getString('radarr_url') ?? '';
    final String radarrApiKey = prefs.getString('radarr_key') ?? '';
    final String sonarrUrl = prefs.getString('sonarr_url') ?? '';
    final String sonarrApiKey = prefs.getString('sonarr_key') ?? '';

    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(days: 7));
    final startStr = now.toIso8601String();
    final endStr = end.toIso8601String();

    // ==========================================
    // 1. 获取 Radarr 电影日历与资讯
    // ==========================================
    if (radarrUrl.isNotEmpty && radarrApiKey.isNotEmpty) {
      try {
        final cleanUrl = radarrUrl.endsWith('/') ? radarrUrl.substring(0, radarrUrl.length - 1) : radarrUrl;
        final radarrRes = await http.get(
          Uri.parse('$cleanUrl/api/v3/calendar?start=$startStr&end=$endStr'),
          headers: {'X-Api-Key': radarrApiKey},
        );
        
        if (radarrRes.statusCode == 200) {
          final List radarrData = jsonDecode(radarrRes.body);
          for (var item in radarrData) {
            String poster = '';
            if (item['images'] != null && item['images'].isNotEmpty) {
              var posterImg = item['images'].firstWhere((img) => img['coverType'] == 'poster', orElse: () => null);
              if (posterImg != null) {
                poster = _buildImageUrl(posterImg['url'], cleanUrl, radarrApiKey);
              }
            }
            
            String dateStr = item['digitalRelease'] ?? item['physicalRelease'] ?? item['inCinemas'] ?? startStr;
            
            allItems.add(MediaItem(
              title: item['title'] ?? '未知电影',
              date: DateTime.parse(dateStr).toLocal(),
              type: 'Movie',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '等待中',
              overview: item['overview'] ?? '暂无剧情简介',
              runtime: item['runtime'] ?? 0,
              network: item['studio'] ?? '未知厂牌',
            ));
          }
        }
      } catch (e) {
        debugPrint("获取 Radarr 日历失败: $e");
      }
    }

    // ==========================================
    // 2. 获取 Sonarr 剧集日历与资讯
    // ==========================================
    if (sonarrUrl.isNotEmpty && sonarrApiKey.isNotEmpty) {
      try {
        final cleanUrl = sonarrUrl.endsWith('/') ? sonarrUrl.substring(0, sonarrUrl.length - 1) : sonarrUrl;
        final sonarrRes = await http.get(
          Uri.parse('$cleanUrl/api/v3/calendar?start=$startStr&end=$endStr'),
          headers: {'X-Api-Key': sonarrApiKey},
        );
        
        if (sonarrRes.statusCode == 200) {
          final List sonarrData = jsonDecode(sonarrRes.body);
          for (var item in sonarrData) {
            String poster = '';
            if (item['series'] != null && item['series']['images'] != null) {
               var posterImg = item['series']['images'].firstWhere((img) => img['coverType'] == 'poster', orElse: () => null);
               if (posterImg != null) {
                 poster = _buildImageUrl(posterImg['url'], cleanUrl, sonarrApiKey);
               }
            }

            // 格式化季数和集数：例如 S01E02
            String s = item['seasonNumber'].toString().padLeft(2, '0');
            String e = item['episodeNumber'].toString().padLeft(2, '0');
            String epTitle = item['title'] ?? '';

            allItems.add(MediaItem(
              title: "${item['series']['title']} - S${s}E${e}",
              date: DateTime.parse(item['airDateUtc']).toLocal(),
              type: 'Episode',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '待首播',
              overview: item['overview'] ?? item['series']['overview'] ?? '该集暂无简介',
              runtime: item['series']['runtime'] ?? 0,
              network: item['series']['network'] ?? '未知平台',
            ));
          }
        }
      } catch (e) {
        debugPrint("获取 Sonarr 日历失败: $e");
      }
    }

    allItems.sort((a, b) => a.date.compareTo(b.date));
    return allItems;
  }
}
