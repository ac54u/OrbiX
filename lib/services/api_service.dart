import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../core/constants.dart'; // 引入常量
import '../core/utils.dart';     // 引入工具
import 'server_manager.dart';    // 引入 ServerManager

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

  // ✅ 新增：切换备用限速模式 (小乌龟)
  static Future<void> toggleAltSpeedLimitsMode() async {
    _ensureInit();
    try {
      final u = await _url();
      if (u == null) return;
      final opts = await _getOptions();
      await _dio.post(
        '$u/api/v2/transfer/toggleSpeedLimitsMode',
        options: opts,
      );
    } catch (e) {
      print("切换备用限速失败: $e");
      rethrow;
    }
  }

  // ✅ 新增：暂停所有任务
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

  // ✅ 新增：恢复所有任务
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
}