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
import 'package:flutter/foundation.dart';

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

      if (r.data is String) {
        try {
          return jsonDecode(r.data);
        } catch (_) {
          return null;
        }
      }
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
      if (response.data is String) {
        try {
          return jsonDecode(response.data);
        } catch (_) {
          return [];
        }
      }
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
      if (r.data is String) {
        try { return jsonDecode(r.data); } catch (_) { return null; }
      }
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
      if (r.data is String) {
        try { return jsonDecode(r.data) as Map<String, dynamic>; } catch (_) { return {}; }
      }
      return r.data is Map ? r.data as Map<String, dynamic> : {};
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
      if (r.data is String) {
        try { return (jsonDecode(r.data) as List).map((e) => e.toString()).toList(); } catch (_) { return []; }
      }
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
      if (r.data is String) {
         try { return jsonDecode(r.data); } catch (_) { return null; }
      }
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
      if (r.data is String) {
         try { return jsonDecode(r.data); } catch (_) { return null; }
      }
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
      if (r.data is String) {
         try { return jsonDecode(r.data); } catch (_) { return null; }
      }
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
      if (r.data is String) {
         try { return jsonDecode(r.data); } catch (_) { return []; }
      }
      return r.data is List ? r.data : [];
    } catch (e) {
      return [];
    }
  }

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
      final opts = await _getOptions();

      final trackerString = bestTrackers.join('\n');

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
      if (r.data is String) return jsonDecode(r.data);
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

      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (data['results'] != null && (data['results'] as List).isNotEmpty) {
        return data['results'][0];
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
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      return (data['cast'] as List).take(10).toList();
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
      if (r.data is String) return jsonDecode(r.data);
      return r.data;
    } catch (e) {
      throw "Radarr 连接失败: $e";
    }
  }

  static Future<String?> checkMovieInEmby(String tmdbId, {String? title}) async {
    _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final key = prefs.getString('emby_api_key') ?? '';

    if (url.isEmpty || key.isEmpty) return null;

    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    try {
      var response = await _dio.get(
        '$cleanUrl/emby/Items',
        queryParameters: {
          'AnyProviderIdEquals': tmdbId,
          'Recursive': 'true',
          'api_key': key,
        }
      );

      var data = response.data is String ? jsonDecode(response.data) : response.data;
      if (response.statusCode == 200 && data['TotalRecordCount'] != null && data['TotalRecordCount'] > 0) {
        return data['Items'][0]['Id'].toString();
      }

      if (title != null && title.isNotEmpty) {
        response = await _dio.get(
          '$cleanUrl/emby/Items',
          queryParameters: {
            'SearchTerm': title,
            'Recursive': 'true',
            'api_key': key,
          }
        );
        data = response.data is String ? jsonDecode(response.data) : response.data;
        if (response.statusCode == 200 && data['TotalRecordCount'] != null && data['TotalRecordCount'] > 0) {
          return data['Items'][0]['Id'].toString();
        }
      }
    } catch (e) {
      debugPrint("Emby 搜索异常: $e");
    }
    return null;
  }

  static Future<String?> getEmbyStreamUrl(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('emby_url') ?? '';
    final key = prefs.getString('emby_api_key') ?? '';

    if (url.isEmpty || key.isEmpty) return null;
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    return '$cleanUrl/emby/Videos/$itemId/stream?static=true&api_key=$key';
  }

  static Future<String?> getDirectStreamUrl(String torrentName) async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('orbix_api_url') ?? 'https://api.dmitt.com/api/sync';
    final apiToken = prefs.getString('orbix_api_token') ?? 'orbix_super_secret_token_2026';

    final baseUrl = apiUrl.replaceAll(RegExp(r'/api/sync$'), '');
    final streamUrl = "$baseUrl/api/stream?token=$apiToken&torrent_name=${Uri.encodeComponent(torrentName)}";
    debugPrint("🚀 物理直连播放地址: $streamUrl");
    return streamUrl;
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

      final pData = profilesResp.data is String ? jsonDecode(profilesResp.data) : profilesResp.data;
      final fData = foldersResp.data is String ? jsonDecode(foldersResp.data) : foldersResp.data;

      if ((pData as List).isEmpty || (fData as List).isEmpty) {
        throw "Radarr 端缺少基础配置(质量配置或根目录)";
      }

      final profileId = pData[0]['id'];
      final rootPath = fData[0]['path'];

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
      if (r.data is String) return jsonDecode(r.data);
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

      final pData = profilesResp.data is String ? jsonDecode(profilesResp.data) : profilesResp.data;
      final fData = foldersResp.data is String ? jsonDecode(foldersResp.data) : foldersResp.data;
      final lData = languageResp.data is String ? jsonDecode(languageResp.data) : languageResp.data;

      if ((pData as List).isEmpty || (fData as List).isEmpty) {
        throw "Sonarr 端缺少基础配置(质量配置或根目录)";
      }

      final profileId = pData[0]['id'];
      final rootPath = fData[0]['path'];
      final languageProfileId = (lData as List).isNotEmpty ? lData[0]['id'] : 1;

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
      if (r.data is String) return jsonDecode(r.data);
      return r.data as List<dynamic>;
    } catch (e) {
      print("获取 Radarr Release 失败: $e");
      return [];
    }
  }

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

      final data = checkResp.data is String ? jsonDecode(checkResp.data) : checkResp.data;
      if ((data as List).isNotEmpty) {
        return data[0]['id'];
      }

      final tempMovieData = Map<String, dynamic>.from(movieData);
      tempMovieData['addOptions'] = {'searchForMovie': false};

      bool added = await addMovieToRadarr(tempMovieData);
      if (added) {
        final recheck = await _dio.get(
          '$url/api/v3/movie',
          queryParameters: {'tmdbId': movieData['tmdbId']},
          options: Options(headers: {'X-Api-Key': key}),
        );
        final reData = recheck.data is String ? jsonDecode(recheck.data) : recheck.data;
        return reData[0]['id'];
      }
    } catch (e) {
      print("检查/添加电影失败: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> checkAppUpdate(String currentVersion) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/ac54u/OrbiX/releases/latest',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        if (data is Map) {
          String latestTag = data['tag_name']?.toString().replaceAll('v', '') ?? '';
          String current = currentVersion.replaceAll('v', '');

          if (_isNewerVersion(latestTag, current)) {
            String downloadUrl = data['html_url'];
            String ipaUrl = '';

            if (data['assets'] != null) {
              for (var asset in data['assets']) {
                if (asset['name'].toString().endsWith('.ipa')) {
                  ipaUrl = asset['browser_download_url'];
                  break;
                }
              }
            }

            return {
              'hasUpdate': true,
              'version': latestTag,
              'notes': data['body'] ?? '常规细节优化与 Bug 修复。',
              'ipaUrl': ipaUrl,
              'url': downloadUrl,
            };
          }
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

  static Future<bool> requestTranslation(String torrentName) async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('orbix_api_url') ?? 'https://api.dmitt.com';
    final baseUrl = apiUrl.replaceAll(RegExp(r'/api/sync$'), '');

    try {
      final r = await _dio.post(
        '$baseUrl/api/translate',
        data: {'torrent_name': torrentName},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return r.statusCode == 200 || r.statusCode == 202;
    } catch (e) {
      debugPrint("翻译请求发送失败: $e");
      return false;
    }
  }
}

// ==========================================
// 🌟 全新的专属 MeTube API 服务
// ==========================================
class MyTubeService {
  // 你的专属 MeTube 服务器地址
  static const String baseUrl = "http://152.53.131.108:5551";
  static final Dio _dio = Dio();

  /// 提交下载任务到 MeTube
  /// 返回 null 表示成功，返回 String 表示错误信息
  static Future<String?> addDownloadTask(String url) async {
    try {
      final response = await _dio.post(
        "$baseUrl/add",
        data: {
          "url": url,
          "quality": "best" // 默认最高画质
        },
        options: Options(
          contentType: Headers.jsonContentType,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        // Dio 自动将响应体解析为 Map
        final data = response.data is String ? jsonDecode(response.data) : response.data;

        // MeTube 添加成功通常返回 {"status": "ok"}
        if (data != null && data['status'] == 'ok') {
          return null; // 成功
        } else {
          return data['error']?.toString() ?? "MeTube 返回未知错误";
        }
      } else {
        return "服务器响应异常，状态码: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("MeTube 请求失败: $e");
      return "无法连接到 MeTube，请检查服务器或网络状态";
    }
  }
}