import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils.dart'; 

class MediaItem {
  final String title;
  final DateTime date;
  final String type; 
  final String posterUrl;
  final String status;
  final String overview; 
  final int runtime;     
  final String network;  

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
            
            // 🚀 防弹解析 1：安全提取海报
            String poster = '';
            if (item['images'] is List) {
              for (var img in item['images']) {
                if (img is Map && img['coverType'] == 'poster' && img['url'] != null) {
                  poster = _buildImageUrl(img['url'].toString(), cleanUrl, radarrApiKey);
                  break; // 找到一张就行，安全退出循环
                }
              }
            }
            
            // 🚀 防弹解析 2：安全解析日期，失败则退回当前时间
            String dateStr = item['digitalRelease']?.toString() ?? 
                             item['physicalRelease']?.toString() ?? 
                             item['inCinemas']?.toString() ?? 
                             startStr;
            DateTime parsedDate = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
            
            // 🚀 防弹解析 3：安全转换时长
            int rTime = int.tryParse(item['runtime']?.toString() ?? '0') ?? 0;
            
            allItems.add(MediaItem(
              title: item['title']?.toString() ?? '未知电影',
              date: parsedDate,
              type: 'Movie',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '等待中',
              overview: item['overview']?.toString() ?? '暂无剧情简介',
              runtime: rTime,
              network: item['studio']?.toString() ?? '未知厂牌',
            ));
          }
        } else {
          Utils.showToast("Radarr: HTTP ${radarrRes.statusCode}");
        }
      } catch (e) {
        debugPrint("获取 Radarr 日历失败: $e");
        // 🚀 把具体的错误也抛出来，如果再报错，截个图就能一秒定位
        Utils.showToast("Radarr 错误: ${e.toString().substring(0, e.toString().length > 30 ? 30 : e.toString().length)}");
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
            
            // 🚀 防弹解析：安全的 Map 检查
            bool hasSeriesMap = item['series'] is Map;

            String poster = '';
            if (hasSeriesMap && item['series']['images'] is List) {
              for (var img in item['series']['images']) {
                if (img is Map && img['coverType'] == 'poster' && img['url'] != null) {
                  poster = _buildImageUrl(img['url'].toString(), cleanUrl, sonarrApiKey);
                  break;
                }
              }
            }

            String s = (item['seasonNumber'] ?? 0).toString().padLeft(2, '0');
            String e = (item['episodeNumber'] ?? 0).toString().padLeft(2, '0');
            String seriesTitle = hasSeriesMap ? (item['series']['title']?.toString() ?? '未知剧集') : '未知剧集';

            String dateStr = item['airDateUtc']?.toString() ?? startStr;
            DateTime parsedDate = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

            int rTime = hasSeriesMap ? (int.tryParse(item['series']['runtime']?.toString() ?? '0') ?? 0) : 0;
            String network = hasSeriesMap ? (item['series']['network']?.toString() ?? '未知平台') : '未知平台';
            String overview = item['overview']?.toString() ?? (hasSeriesMap ? item['series']['overview']?.toString() : null) ?? '该集暂无简介';

            allItems.add(MediaItem(
              title: "$seriesTitle - S${s}E${e}",
              date: parsedDate,
              type: 'Episode',
              posterUrl: poster,
              status: item['hasFile'] == true ? '已下载' : '待首播',
              overview: overview,
              runtime: rTime,
              network: network,
            ));
          }
        } else {
          Utils.showToast("Sonarr: HTTP ${sonarrRes.statusCode}");
        }
      } catch (e) {
        debugPrint("获取 Sonarr 日历失败: $e");
        Utils.showToast("Sonarr 错误: ${e.toString().substring(0, e.toString().length > 30 ? 30 : e.toString().length)}");
      }
    }

    allItems.sort((a, b) => a.date.compareTo(b.date));
    return allItems;
  }
}
