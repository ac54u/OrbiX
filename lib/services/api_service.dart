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
import 'package:flutter/foundation.dart'; // 🌟 解决 debugPrint 找不到的问题

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

  static Future<String?> setLocation(String hash, String location) async {
    _ensureInit();
    try {
      final u = await _url();
      if (u == null) return "未连接到服务器";
      final opts = await _getOptions();

      final body = 'hashes=$hash&location=${Uri.encodeComponent(location)}';

      final r = await _dio.post(
        '$u/api/v2/torrents/setLocation',
        data: body,
        options: opts.copyWith(contentType: Headers.formUrlEncodedContentType),
      );

      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
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


// 🌟 1. 从全球最大的开源 Tracker 库获取“神级”节点列表
  static Future<List<String>> fetchBestTrackers() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      if (response.statusCode == 200) {
        List<String> trackers = response.data
            .toString()
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return trackers;
      }
    } catch (e) {
      debugPrint("获取 Tracker 失败: $e");
    }
    return [];
  }

  // 🌟 2. 智能注入 Tracker 到 qBittorrent 任务 (已修复请求逻辑)
  static Future<bool> injectTrackers(String hash, bool isPrivate) async {
    if (isPrivate) {
      Utils.showToast("⚠️ 保护机制触发：禁止给 PT 种子添加 Tracker！");
      return false;
    }

    Utils.showToast("正在请求全球最新 Tracker...");
    List<String> bestTrackers = await fetchBestTrackers();

    if (bestTrackers.isEmpty) {
      Utils.showToast("❌ 网络异常，获取 Tracker 失败");
      return false;
    }

    _ensureInit();
    try {
      final u = await _url();
      if (u == null) return false;
      final opts = await _getOptions(); // 🌟 必须获取 Cookie，否则 qB 会报 403

      final trackerString = bestTrackers.join('\n');

      // 🌟 修复 _qbDio 未定义，并使用标准表单数据格式提交
      final response = await _dio.post(
        '$u/api/v2/torrents/addTrackers',
        data: 'hash=$hash&urls=${Uri.encodeComponent(trackerString)}',
        options: opts.copyWith(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        Utils.showToast("💉 成功注入 ${bestTrackers.length} 个优质节点！");
        return true;
      }
    } catch (e) {
      debugPrint("注入 Tracker 异常: $e");
      Utils.showToast("❌ 注入失败，请检查 qB 连接");
    }
    return false;
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

// ==========================================
  // 🌟 终极修复：Emby 双重搜索机制
  // ==========================================
  static Future<String?> checkMovieInEmby(String tmdbId, {String? title}) async {
    _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final key = prefs.getString('emby_api_key') ?? '';

    if (url.isEmpty || key.isEmpty) return null;

    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    try {
      // 🚀 尝试 1：通过 TMDB ID 精准搜索（已去掉 Movie 限制，完美兼容电视剧/动漫！）
      var response = await _dio.get(
        '$cleanUrl/emby/Items',
        queryParameters: {
          'AnyProviderIdEquals': tmdbId,
          'Recursive': 'true',
          'api_key': key,
        }
      );

      if (response.statusCode == 200 && response.data['TotalRecordCount'] > 0) {
        return response.data['Items'][0]['Id'].toString();
      }

      // 🚀 尝试 2：如果 ID 没搜到（Emby可能用了豆瓣/IMDB刮削），自动降级为“片名模糊搜索”！
      if (title != null && title.isNotEmpty) {
        response = await _dio.get(
          '$cleanUrl/emby/Items',
          queryParameters: {
            'SearchTerm': title,
            'Recursive': 'true',
            'api_key': key,
          }
        );
        if (response.statusCode == 200 && response.data['TotalRecordCount'] > 0) {
          return response.data['Items'][0]['Id'].toString();
        }
      }
    } catch (e) {
      debugPrint("Emby 搜索异常: $e");
    }
    return null;
  }

  // 🌟 新增：获取 Emby 真实流媒体播放地址，供应用内 media_kit 播放器使用
  static Future<String?> getEmbyStreamUrl(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final key = prefs.getString('emby_api_key') ?? '';

    if (url.isEmpty || key.isEmpty) return null;
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    // static=true 告诉 Emby 尽量原画直连（因为我们的播放器足够强大，不需要转码）
    return '$cleanUrl/emby/Videos/$itemId/stream?static=true&api_key=$key';
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
  // --- Sonarr 剧集联动 API ---
  // ==========================================

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

  static Future<bool> addSeriesToSonarr(Map<String, dynamic> seriesData) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('sonarr_url');
    final key = p.getString('sonarr_key');

    try {
      final profilesResp = await _dio.get(
        '$url/api/v3/qualityprofile',
        options: Options(headers: {'X-Api-Key': key}),
      );
      final foldersResp = await _dio.get(
        '$url/api/v3/rootfolder',
        options: Options(headers: {'X-Api-Key': key}),
      );
      final languageResp = await _dio.get(
        '$url/api/v3/languageprofile',
        options: Options(headers: {'X-Api-Key': key}),
      );

      if ((profilesResp.data as List).isEmpty || (foldersResp.data as List).isEmpty) {
        throw "Sonarr 端缺少基础配置(质量配置或根目录)";
      }

      final profileId = profilesResp.data[0]['id'];
      final rootPath = foldersResp.data[0]['path'];
      final languageProfileId = (languageResp.data as List).isNotEmpty ? languageResp.data[0]['id'] : 1;

      final payload = {
        ...seriesData,
        'qualityProfileId': profileId,
        'languageProfileId': languageProfileId,
        'rootFolderPath': rootPath,
        'monitored': true,
        'addOptions': {
          'searchForMissingEpisodes': true
        }
      };

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

  // ==========================================
  // --- 🌟 Radarr 交互式搜索联动 API ---
  // ==========================================

  /// 1. 获取特定电影的所有可用种子资源 (Interactive Search)
  static Future<List<dynamic>> getRadarrReleases(int movieId) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('radarr_url');
    final key = p.getString('radarr_key');

    try {
      final r = await _dio.get(
        '$url/api/v3/release',
        queryParameters: {'movieId': movieId},
        options: Options(headers: {'X-Api-Key': key}),
      );
      return r.data as List<dynamic>;
    } catch (e) {
      print("获取 Radarr Release 失败: $e");
      return [];
    }
  }

  /// 2. 推送选中的资源到下载器
  static Future<bool> downloadRadarrRelease(Map<String, dynamic> release) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('radarr_url');
    final key = p.getString('radarr_key');

    try {
      final r = await _dio.post(
        '$url/api/v3/release',
        data: release,
        options: Options(headers: {'X-Api-Key': key}),
      );
      return r.statusCode == 201 || r.statusCode == 200;
    } catch (e) {
      print("推送下载失败: $e");
      return false;
    }
  }

  /// 3. (辅助) 将电影加入 Radarr 库以解锁 Interactive Search
  static Future<int?> ensureMovieInRadarr(Map<String, dynamic> movieData) async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('radarr_url');
    final key = p.getString('radarr_key');

    try {
      final checkResp = await _dio.get(
        '$url/api/v3/movie',
        queryParameters: {'tmdbId': movieData['tmdbId']},
        options: Options(headers: {'X-Api-Key': key}),
      );

      if ((checkResp.data as List).isNotEmpty) {
        return checkResp.data[0]['id'];
      }

      // 不存在则添加，拿到 Radarr 内部的 movieId (这里我们不让它自动搜种子)
      final tempMovieData = Map<String, dynamic>.from(movieData);
      tempMovieData['addOptions'] = {'searchForMovie': false}; // 🌟 覆盖默认配置，防止全自动抢跑

      bool added = await addMovieToRadarr(tempMovieData);
      if (added) {
        final recheck = await _dio.get(
          '$url/api/v3/movie',
          queryParameters: {'tmdbId': movieData['tmdbId']},
          options: Options(headers: {'X-Api-Key': key}),
        );
        return recheck.data[0]['id'];
      }
    } catch (e) {
      print("检查/添加电影失败: $e");
    }
    return null;
  }


  // ==========================================
  // --- 🌟 GitHub OTA 热更新探针 ---
  // ==========================================

  static Future<Map<String, dynamic>?> checkAppUpdate(String currentVersion) async {
    try {
      final dio = Dio();
      // 直连抓取你的仓库最新 Release
      final response = await dio.get(
        'https://api.github.com/repos/ac54u/OrbiX/releases/latest',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      if (response.statusCode == 200) {
        String latestTag = response.data['tag_name']?.toString().replaceAll('v', '') ?? '';
        String current = currentVersion.replaceAll('v', '');

        if (_isNewerVersion(latestTag, current)) {
          String downloadUrl = response.data['html_url'];
          String ipaUrl = '';

          // 智能提取 .ipa 格式的资源，用于巨魔直装
          if (response.data['assets'] != null) {
            for (var asset in response.data['assets']) {
              if (asset['name'].toString().endsWith('.ipa')) {
                ipaUrl = asset['browser_download_url'];
                break;
              }
            }
          }

          return {
            'hasUpdate': true,
            'version': latestTag,
            'notes': response.data['body'] ?? '常规细节优化与 Bug 修复。',
            'ipaUrl': ipaUrl,
            'url': downloadUrl,
          };
        }
      }
    } catch (e) {
      debugPrint("获取 GitHub Release 失败: $e");
    }
    return null;
  }

  static bool _isNewerVersion(String latest, String current) {
    try {
      List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        int lv = i < l.length ? l[i] : 0;
        int cv = i < c.length ? c[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
    } catch (_) {}
    return false;
  }
}