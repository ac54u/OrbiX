import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../core/constants.dart'; 
import '../core/utils.dart';     
import 'server_manager.dart';    
import 'package:url_launcher/url_launcher.dart';

class ApiService {
  static final Dio _dio = Dio();
  static bool _init = false;

  static void _ensureInit() {
    if (_init) return;
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
    _dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
    _init = true;
  }

  static Future<String?> _url({Map<String, dynamic>? overrideConfig}) async {
    Map<String, dynamic>? server;
    if (overrideConfig != null) {
      server = overrideConfig;
    } else {
      server = await ServerManager.getCurrentServer();
    }
    if (server == null) return null;
    final h = server['host'];
    final port = server['port'];
    final useHttps = server['https'] ?? false;
    return "${useHttps ? 'https' : 'http'}://$h:$port";
  }

  static Future<Options> _getOptions() async {
    final u = await _url();
    final prefs = await SharedPreferences.getInstance();
    return Options(
      headers: {'Cookie': prefs.getString('cookie'), 'Referer': u},
      followRedirects: false,
      validateStatus: (status) => true,
    );
  }

  static Future<bool> testConnection(Map<String, dynamic> config) async {
    return await login(overrideConfig: config);
  }

  static Future<bool> login({Map<String, dynamic>? overrideConfig}) async {
    _ensureInit();
    try {
      final u = await _url(overrideConfig: overrideConfig);
      if (u == null) return false;
      Map<String, dynamic>? server =
          overrideConfig ?? await ServerManager.getCurrentServer();
      if (server == null) return false;

      final r = await _dio.post(
        '$u/api/v2/auth/login',
        data: {'username': server['user'], 'password': server['pass']},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Referer': u},
          followRedirects: false,
          validateStatus: (status) => true,
        ),
      );

      final cookies = r.headers['set-cookie'];
      final prefs = await SharedPreferences.getInstance();
      if (cookies != null) {
        for (final c in cookies) {
          if (c.startsWith('SID=')) {
            await prefs.setString('cookie', c.split(';').first);
            
            // 🔒 专属防盗锁：只有登录你自己的 qB 时，才去拉取云端高级配置！
            if (server['host'].toString().contains('qb.dmitt.com') || 
                server['host'].toString().contains('69.63.217.175')) {
              autoFetchCloudConfig();
            }
            
            return true;
          }
        }
      }

      if (overrideConfig == null) {
        final oldCookie = prefs.getString('cookie');
        if (oldCookie != null && oldCookie.startsWith('SID=')) return true;
      }
      return false;
    } catch (e, stack) {
      await Sentry.captureException(e, stackTrace: stack);
      return false;
    }
  }

  static Future<List<dynamic>?> getTorrents({
    String filter = 'all',
    String? category,
    String? tag,
  }) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final Map<String, dynamic> query = {'filter': filter};
      if (category != null && category != 'all') query['category'] = category;
      if (tag != null && tag != 'all') query['tag'] = tag;

      final r = await _dio.get(
        '$u/api/v2/torrents/info',
        queryParameters: query,
        options: opts,
      );
      if (r.data is String) return jsonDecode(r.data);
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getTorrentContent(String hash) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final response = await _dio.get(
        '$u/api/v2/torrents/files',
        queryParameters: {'hash': hash},
        options: opts,
      );
      return response.data as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  static Future<String?> controlTorrent(String hash, String command) async {
    _ensureInit();
    if (!Utils.isValidHash(hash)) return "无效的 Hash";
    try {
      final u = await _url();
      final opts = await _getOptions();
      String endpoint = command;
      String body = 'hashes=$hash';

      if (command == 'setForceStart') body += '&value=true';
      if (['topPrio', 'bottomPrio', 'increasePrio', 'decreasePrio']
          .contains(command)) {
        endpoint = command; 
      }

      final r = await _dio.post(
        '$u/api/v2/torrents/$endpoint',
        data: body,
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );

      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
    }
  }

  static Future<void> pauseAll() async {
    _ensureInit();
    try {
      final u = await _url();
      if (u == null) return;
      final opts = await _getOptions();
      await _dio.post(
        '$u/api/v2/torrents/pause',
        data: 'hashes=all',
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      print("暂停所有任务失败: $e");
      rethrow;
    }
  }

  static Future<void> resumeAll() async {
    _ensureInit();
    try {
      final u = await _url();
      if (u == null) return;
      final opts = await _getOptions();
      await _dio.post(
        '$u/api/v2/torrents/resume',
        data: 'hashes=all',
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (e) {
      print("恢复所有任务失败: $e");
      rethrow;
    }
  }

  static Future<String?> deleteTorrent(String hash, bool deleteFiles) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final body = 'hashes=$hash&deleteFiles=$deleteFiles';

      final r = await _dio.post(
        '$u/api/v2/torrents/delete',
        data: body,
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
    }
  }

  static Future<bool> addTorrent(
    String urls, {
    String? savePath,
    String? category,
    String? tags,
  }) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final formData = FormData.fromMap({
        'urls': urls,
        if (savePath != null) 'savepath': savePath,
        if (category != null) 'category': category,
        if (tags != null) 'tags': tags,
      });

      await _dio.post('$u/api/v2/torrents/add', data: formData, options: opts);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> addTorrentFile(
    String filePath, {
    String? savePath,
    String? category,
    String? tags,
  }) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      String fileName = filePath.split('/').last;

      FormData formData = FormData.fromMap({
        'torrents': await MultipartFile.fromFile(filePath, filename: fileName),
        if (savePath != null) 'savepath': savePath,
        if (category != null) 'category': category,
        if (tags != null) 'tags': tags,
      });

      await _dio.post('$u/api/v2/torrents/add', data: formData, options: opts);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> setPreferences({required String savePath}) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final data = {
        'json': jsonEncode({'save_path': savePath})
      };
      
      final response = await _dio.post(
        '$u/api/v2/app/setPreferences',
        data: FormData.fromMap(data),
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Set preferences error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getMainData() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get('$u/api/v2/sync/maindata', options: opts);
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getCategories() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get('$u/api/v2/torrents/categories', options: opts);
      return r.data is Map ? r.data : {};
    } catch (e) {
      return {};
    }
  }

  static Future<List<String>> getTags() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get('$u/api/v2/torrents/tags', options: opts);
      return (r.data as List).map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTransferInfo() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get('$u/api/v2/transfer/info', options: opts);
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> setTransferLimit(
      {int? dlLimitBytes, int? upLimitBytes}) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final ct = opts.copyWith(contentType: Headers.formUrlEncodedContentType);

      if (dlLimitBytes != null) {
        await _dio.post(
          '$u/api/v2/transfer/setDownloadLimit',
          data: 'limit=$dlLimitBytes',
          options: ct,
        );
      }
      if (upLimitBytes != null) {
        await _dio.post(
          '$u/api/v2/transfer/setUploadLimit',
          data: 'limit=$upLimitBytes',
          options: ct,
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>?> getTorrentFiles(String hash) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get(
        '$u/api/v2/torrents/files?hash=$hash',
        options: opts,
      );
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getTorrentPeers(String hash) async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get(
        '$u/api/v2/sync/torrentPeers?hash=$hash',
        options: opts,
      );
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getAppVersion() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get('$u/api/v2/app/version', options: opts);
      return r.data.toString();
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getServerLogs() async {
    _ensureInit();
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get(
        '$u/api/v2/log/main',
        queryParameters: {
          'normal': 'true',
          'info': 'true',
          'warning': 'true',
          'critical': 'true',
          'last_known_id': -1
        },
        options: opts,
      );
      return r.data is List ? r.data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> searchProwlarr(String query) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('prowlarr_url');
    final key = p.getString('prowlarr_key');

    if (url == null || key == null || key.isEmpty) throw "请先在设置中配置 Prowlarr";

    try {
      final r = await _dio.get(
        '$url/api/v1/search',
        queryParameters: {'query': query, 'type': 'search'},
        options: Options(headers: {'X-Api-Key': key}),
      );
      return r.data;
    } catch (e) {
      throw "Prowlarr 连接失败";
    }
  }

  static Future<Map<String, dynamic>?> searchTMDB(
    String title, {
    String? year,
  }) async {
    final p = await SharedPreferences.getInstance();
    String key = p.getString('tmdb_key') ?? '';
    if (key.isEmpty) key = kDefaultTmdbKey;

    try {
      final r = await _dio.get(
        'https://api.themoviedb.org/3/search/movie',
        queryParameters: {
          'api_key': key,
          'query': title,
          'language': 'zh-CN',
          if (year != null) 'year': year,
        },
      );
      if (r.data['results'] != null && (r.data['results'] as List).isNotEmpty) {
        return r.data['results'][0];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static Future<List<dynamic>> getTMDBCredits(int id) async {
    final p = await SharedPreferences.getInstance();
    String key = p.getString('tmdb_key') ?? '';
    if (key.isEmpty) key = kDefaultTmdbKey;

    try {
      final r = await _dio.get(
        'https://api.themoviedb.org/3/movie/$id/credits',
        queryParameters: {'api_key': key},
      );
      return (r.data['cast'] as List).take(10).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> searchRadarr(String query) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('radarr_url');
    final key = p.getString('radarr_key');

    if (url == null || key == null || key.isEmpty) throw "请先在设置中配置 Radarr 地址和 Key";

    try {
      final r = await _dio.get(
        '$url/api/v3/movie/lookup',
        queryParameters: {'term': query},
        options: Options(headers: {'X-Api-Key': key}),
      );
      return r.data;
    } catch (e) {
      throw "Radarr 连接失败: $e";
    }
  }

  static Future<String?> checkMovieInEmby(String tmdbId) async {
    _ensureInit(); 
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final key = prefs.getString('emby_api_key') ?? '';

    if (url.isEmpty || key.isEmpty) return null;

    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    
    try {
      final response = await _dio.get(
        '$cleanUrl/emby/Items',
        queryParameters: {
          'AnyProviderIdEquals': tmdbId,
          'Recursive': 'true',
          'IncludeItemTypes': 'Movie',
          'api_key': key,
        }
      );
      if (response.statusCode == 200) {
        final data = response.data; 
        if (data['TotalRecordCount'] != null && data['TotalRecordCount'] > 0) {
          return data['Items'][0]['Id'].toString(); 
        }
      }
    } catch (e) {
      print("Check Emby error: $e");
    }
    return null; 
  }

  static Future<void> playInEmby(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    final playUrl = Uri.parse('$cleanUrl/web/index.html#!/item/item.html?id=$itemId');
    
    if (await canLaunchUrl(playUrl)) {
      await launchUrl(playUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception("无法拉起 Emby");
    }
  }

  static Future<bool> addMovieToRadarr(Map<String, dynamic> movieData) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('radarr_url');
    final key = p.getString('radarr_key');

    try {
      final profilesResp = await _dio.get(
        '$url/api/v3/qualityprofile',
        options: Options(headers: {'X-Api-Key': key}),
      );
      final foldersResp = await _dio.get(
        '$url/api/v3/rootfolder',
        options: Options(headers: {'X-Api-Key': key}),
      );

      if ((profilesResp.data as List).isEmpty || (foldersResp.data as List).isEmpty) {
        throw "Radarr 端缺少基础配置(质量配置或根目录)";
      }

      final profileId = profilesResp.data[0]['id'];
      final rootPath = foldersResp.data[0]['path'];

      final payload = {
        ...movieData,
        'qualityProfileId': profileId,
        'rootFolderPath': rootPath,
        'monitored': true,
        'addOptions': {
          'searchForMovie': true 
        }
      };

      final r = await _dio.post(
        '$url/api/v3/movie',
        data: payload,
        options: Options(headers: {'X-Api-Key': key}),
      );

      return r.statusCode == 201 || r.statusCode == 200;
    } catch (e) {
      print("添加至 Radarr 失败: $e");
      return false;
    }
  }

  // ==========================================
  // --- Sonarr 剧集联动 API (新增) ---
  // ==========================================

  /// 🔍 搜索 Sonarr 剧集
  static Future<List<dynamic>> searchSonarr(String query) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('sonarr_url');
    final key = p.getString('sonarr_key');

    if (url == null || key == null || key.isEmpty) throw "请先在设置中配置 Sonarr 地址和 Key";

    try {
      final r = await _dio.get(
        '$url/api/v3/series/lookup',
        queryParameters: {'term': query},
        options: Options(headers: {'X-Api-Key': key}),
      );
      return r.data;
    } catch (e) {
      throw "Sonarr 连接失败: $e";
    }
  }

  /// ✅ 将剧集添加到 Sonarr 监控并自动搜索下载
  static Future<bool> addSeriesToSonarr(Map<String, dynamic> seriesData) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('sonarr_url');
    final key = p.getString('sonarr_key');

    try {
      // 1. 获取基础配置
      final profilesResp = await _dio.get(
        '$url/api/v3/qualityprofile',
        options: Options(headers: {'X-Api-Key': key}),
      );
      final foldersResp = await _dio.get(
        '$url/api/v3/rootfolder',
        options: Options(headers: {'X-Api-Key': key}),
      );
      final languageResp = await _dio.get(
        '$url/api/v3/languageprofile', // Sonarr v3 需要语言配置
        options: Options(headers: {'X-Api-Key': key}),
      );

      if ((profilesResp.data as List).isEmpty || (foldersResp.data as List).isEmpty) {
        throw "Sonarr 端缺少基础配置(质量配置或根目录)";
      }

      // 2. 提取默认配置的 ID
      final profileId = profilesResp.data[0]['id'];
      final rootPath = foldersResp.data[0]['path'];
      final languageProfileId = (languageResp.data as List).isNotEmpty ? languageResp.data[0]['id'] : 1;

      // 3. 组装提交给 Sonarr 的 Payload
      final payload = {
        ...seriesData,
        'qualityProfileId': profileId,
        'languageProfileId': languageProfileId,
        'rootFolderPath': rootPath,
        'monitored': true,
        'addOptions': {
          'searchForMissingEpisodes': true // 添加后立即搜索缺失的剧集
        }
      };

      // 4. 发送添加请求
      final r = await _dio.post(
        '$url/api/v3/series',
        data: payload,
        options: Options(headers: {'X-Api-Key': key}),
      );

      return r.statusCode == 201 || r.statusCode == 200;
    } catch (e) {
      print("添加至 Sonarr 失败: $e");
      return false;
    }
  }

  // ✅ 新增：无感拉取云端配置 (Zero-Config)
  static Future<void> autoFetchCloudConfig() async {
    try {
      // ⚠️ 已替换为你的新服务器 IP
      final apiUrl = "http://64.186.241.43:3000/api/orbix_config?token=hahayes2026"; 
      
      final r = await Dio().get(apiUrl);
      if (r.data != null && r.data['success'] == true) {
        final config = r.data['data'];
        final p = await SharedPreferences.getInstance();
        
        // 自动装载到手机本地
        if (config['prowlarr_url'] != null) await p.setString('prowlarr_url', config['prowlarr_url']);
        if (config['prowlarr_key'] != null) await p.setString('prowlarr_key', config['prowlarr_key']);
        if (config['radarr_url'] != null) await p.setString('radarr_url', config['radarr_url']);
        if (config['radarr_key'] != null) await p.setString('radarr_key', config['radarr_key']);
        if (config['sonarr_url'] != null) await p.setString('sonarr_url', config['sonarr_url']);
        if (config['sonarr_key'] != null) await p.setString('sonarr_key', config['sonarr_key']);
        if (config['emby_url'] != null) await p.setString('emby_url', config['emby_url']);
        if (config['emby_key'] != null) await p.setString('emby_key', config['emby_key']);
        if (config['tmdb_key'] != null) await p.setString('tmdb_key', config['tmdb_key']);
        
        print("🎉 云端聚合配置已无感下发并装载完毕！");
      }
    } catch (e) {
      print("静默拉取云端配置失败: $e");
    }
  }
}
