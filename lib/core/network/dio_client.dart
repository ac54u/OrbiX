import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart'; // 引入 kDebugMode

class DioClient {
  /// 生产一个配置好的独立 Dio 实例
  static Dio create({bool followRedirects = false}) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: followRedirects,
      validateStatus: (status) => true, // 接收所有状态码，业务层自行处理
    ));

    // 🌟 核心安全修复：仅在 Debug 模式下允许抓包和忽略证书校验！
    // 正式打包发布 (Release) 时，这段代码会自动失效，强制验证 HTTPS 证书防劫持！
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (kDebugMode) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        }
        return client;
      },
    );

    // 仅在开发环境打印网络日志，保持控制台清爽
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }

    return dio;
  }
}