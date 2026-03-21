import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 引入本地存储

// 统一的媒体数据模型，方便 UI 渲染
class MediaItem {
  final String title;
  final DateTime date;
  final String type; // 'Movie' 或 'Episode'
  final String posterUrl;
  final String status;

  MediaItem({
    required this.title,
    required this.date,
    required this.type,
    required this.posterUrl,
    required this.status,
  });
}

class ArrApiService {
  
  /// 获取未来 7 天的媒体日历（合并 Radarr 和 Sonarr）
  static Future<List<MediaItem>> getUpcomingCalendar() async {
    List<MediaItem> allItems = [];
    
    // 🚀 动态读取设置里的配置
    final prefs = await SharedPreferences.getInstance();
    final String radarrUrl = prefs.getString('radarr_url') ?? '';
    final String radarrApiKey = prefs.getString('radarr_key') ?? '';
    final String sonarrUrl = prefs.getString('sonarr_url') ?? '';
    final String sonarrApiKey = prefs.getString('sonarr_key') ?? '';

    // 计算时间范围：今天 到 7天后
    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(days: 7));
    final startStr = now.toIso8601String();
    final endStr = end.toIso8601String();

    // ==========================================
    // 1. 获取 Radarr 电影日历
    // ==========================================
    if (radarrUrl.isNotEmpty && radarrApiKey.isNotEmpty) {
      try {
        // 清理 URL 结尾可能多余的斜杠
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
                poster = '$cleanUrl${posterImg['url']}&apikey=$radarrApiKey';
              }
            }
            
            String dateStr = item['digitalRelease'] ?? item['physicalRelease'] ?? item['inCinemas'] ?? startStr;
            
            allItems.add(MediaItem(
              title: item['title'] ?? '未知电影',
              date: DateTime.parse(dateStr).toLocal(),
              type: 'Movie',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '等待中',
            ));
          }
        }
      } catch (e) {
        debugPrint("获取 Radarr 日历失败: $e");
      }
    }

    // ==========================================
    // 2. 获取 Sonarr 剧集日历
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
                 poster = '$cleanUrl${posterImg['url']}&apikey=$sonarrApiKey';
               }
            }

            allItems.add(MediaItem(
              title: "${item['series']['title']} - S${item['seasonNumber']}E${item['episodeNumber']}",
              date: DateTime.parse(item['airDateUtc']).toLocal(),
              type: 'Episode',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '待首播',
            ));
          }
        }
      } catch (e) {
        debugPrint("获取 Sonarr 日历失败: $e");
      }
    }

    // 按时间先后顺序排序
    allItems.sort((a, b) => a.date.compareTo(b.date));
    
    return allItems;
  }
}