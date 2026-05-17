import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart'; // 引入刚刚建的网络基座
import '../core/utils.dart';
import 'server_manager.dart';

class QbService {
  // 🌟 独立的 Dio 实例，绝不污染其他 API
  static final Dio _dio = DioClient.create(followRedirects: false);

  // 内部辅助方法：获取 qB 服务器地址
  static Future<String?> _url({Map<String, dynamic>? overrideConfig}) async {
    Map<String, dynamic>? server = overrideConfig ?? await ServerManager.getCurrentServer();
    if (server == null) return null;
    final h = server['host'];
    final port = server['port'];
    final useHttps = server['https'] ?? false;
    return "${useHttps ? 'https' : 'http'}://$h:$port";
  }

  // 内部辅助方法：统一拦截并注入 Cookie 和 Referer
  static Future<Options> _getOptions({String? customContentType}) async {
    final u = await _url();
    final prefs = await SharedPreferences.getInstance();
    return Options(
      headers: {'Cookie': prefs.getString('cookie'), 'Referer': u},
      contentType: customContentType,
    );
  }

  // ==========================================
  // --- 身份认证 API ---
  // ==========================================
  static Future<bool> testConnection(Map<String, dynamic> config) async {
    return await login(overrideConfig: config);
  }

  static Future<bool> login({Map<String, dynamic>? overrideConfig}) async {
    try {
      final u = await _url(overrideConfig: overrideConfig);
      if (u == null) return false;
      Map<String, dynamic>? server = overrideConfig ?? await ServerManager.getCurrentServer();
      if (server == null) return false;

      // 🔴 核心修复：强制使用 application/x-www-form-urlencoded 的字符串格式！
      final String requestBody = 'username=${Uri.encodeComponent(server['user'])}&password=${Uri.encodeComponent(server['pass'])}';

      debugPrint("正在尝试登录 qB: $u/api/v2/auth/login");

      final r = await _dio.post(
        '$u/api/v2/auth/login',
        data: requestBody, // 使用原生的 URL-encoded 字符串
        options: Options(
          contentType: Headers.formUrlEncodedContentType, // 明确告知是表单
          headers: {'Referer': u}, // qB 强制要求 Referer
        ),
      );

      debugPrint("qB 登录响应状态: ${r.statusCode}, Headers: ${r.headers}");

      final cookies = r.headers['set-cookie'];
      final prefs = await SharedPreferences.getInstance();
      
      if (cookies != null && cookies.isNotEmpty) {
        for (final c in cookies) {
          if (c.startsWith('SID=')) {
            await prefs.setString('cookie', c.split(';').first);
            debugPrint("✅ 成功提取并保存 SID Cookie!");
            return true;
          }
        }
      }

      // 容错逻辑：如果没拿到新 Cookie，但本地有老 Cookie，也姑且放行
      if (overrideConfig == null) {
        final oldCookie = prefs.getString('cookie');
        if (oldCookie != null && oldCookie.startsWith('SID=')) return true;
      }
      
      debugPrint("❌ 登录失败：服务器响应了 200，但没有返回 SID Cookie。");
      return false;
      
    } catch (e, stack) {
      if (e is DioException) {
         debugPrint("🔥🔥🔥 qB 登录爆红，Dio 异常: [${e.type}] ${e.message}");
         if (e.response != null) {
           debugPrint("🔥🔥🔥 qB 服务器返回错误状态码: ${e.response?.statusCode}, 数据: ${e.response?.data}");
         }
      } else {
         debugPrint("🔥🔥🔥 qB 登录爆红，未知异常: $e");
      }
      await Sentry.captureException(e, stackTrace: stack);
      return false;
    }
  }

  // ==========================================
  // --- 数据获取 API ---
  // ==========================================
  static Future<List<dynamic>?> getTorrents({String filter = 'all', String? category, String? tag}) async {
    try {
      final u = await _url();
      final opts = await _getOptions();
      final Map<String, dynamic> query = {'filter': filter};
      if (category != null && category != 'all') query['category'] = category;
      if (tag != null && tag != 'all') query['tag'] = tag;

      final r = await _dio.get('$u/api/v2/torrents/info', queryParameters: query, options: opts);
      if (r.data is String) {
        try { return jsonDecode(r.data); } catch (_) { return null; }
      }
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getMainData() async {
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

  static Future<String?> getAppVersion() async {
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
    try {
      final u = await _url();
      final opts = await _getOptions();
      final r = await _dio.get(
        '$u/api/v2/log/main',
        queryParameters: {'normal': 'true', 'info': 'true', 'warning': 'true', 'critical': 'true', 'last_known_id': -1},
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

  // ==========================================
  // --- 种子控制 API ---
  // ==========================================
  static Future<bool> addTorrent(String urls, {String? savePath, String? category, String? tags}) async {
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

  static Future<bool> addTorrentFile(String filePath, {String? savePath, String? category, String? tags}) async {
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

  static Future<String?> controlTorrent(String hash, String command) async {
    if (!Utils.isValidHash(hash)) return "无效的 Hash";
    try {
      final u = await _url();
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      String endpoint = command;
      String body = 'hashes=$hash';

      if (command == 'setForceStart') body += '&value=true';
      if (['topPrio', 'bottomPrio', 'increasePrio', 'decreasePrio'].contains(command)) {
        endpoint = command;
      }

      final r = await _dio.post('$u/api/v2/torrents/$endpoint', data: body, options: opts);
      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
    }
  }

  static Future<void> pauseAll() async {
    try {
      final u = await _url();
      if (u == null) return;
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      await _dio.post('$u/api/v2/torrents/pause', data: 'hashes=all', options: opts);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> resumeAll() async {
    try {
      final u = await _url();
      if (u == null) return;
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      await _dio.post('$u/api/v2/torrents/resume', data: 'hashes=all', options: opts);
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> deleteTorrent(String hash, bool deleteFiles) async {
    try {
      final u = await _url();
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      final r = await _dio.post('$u/api/v2/torrents/delete', data: 'hashes=$hash&deleteFiles=$deleteFiles', options: opts);
      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
    }
  }

  static Future<bool> setPreferences({required String savePath}) async {
    try {
      final u = await _url();
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      final response = await _dio.post(
        '$u/api/v2/app/setPreferences',
        data: FormData.fromMap({'json': jsonEncode({'save_path': savePath})}),
        options: opts,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> setLocation(String hash, String location) async {
    try {
      final u = await _url();
      if (u == null) return "未连接到服务器";
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      final r = await _dio.post('$u/api/v2/torrents/setLocation', data: 'hashes=$hash&location=${Uri.encodeComponent(location)}', options: opts);
      if (r.statusCode == 200) return null;
      return "HTTP ${r.statusCode}";
    } catch (e) {
      return "网络请求异常";
    }
  }

  static Future<bool> setTransferLimit({int? dlLimitBytes, int? upLimitBytes}) async {
    try {
      final u = await _url();
      final opts = await _getOptions(customContentType: Headers.formUrlEncodedContentType);
      if (dlLimitBytes != null) {
        await _dio.post('$u/api/v2/transfer/setDownloadLimit', data: 'limit=$dlLimitBytes', options: opts);
      }
      if (upLimitBytes != null) {
        await _dio.post('$u/api/v2/transfer/setUploadLimit', data: 'limit=$upLimitBytes', options: opts);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}