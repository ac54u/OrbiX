import 'dart:io';
import 'dart:convert';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class JavExploreScreen extends StatefulWidget {
  const JavExploreScreen({super.key});

  @override
  State<JavExploreScreen> createState() => _JavExploreScreenState();
}

class _JavExploreScreenState extends State<JavExploreScreen> {
  bool _isLoading = true;
  List<Map<String, String>> _resources = [];
  String _errorMessage = "";

  static String? _busCookie;
  String _currentEngine = '141jav';
  String _currentCategory = '';

  final Map<String, String> _categories141 = {
    '': '首页',
    'new': '最新',
    'popular/': '热门',
    'random/': '随机',
  };

  final Map<String, String> _categoriesBus = {
    '': '有码',
    'uncensored': '无码',
    'genre/hd': '高清',
    'genre/sub': '中字',
  };

  final List<String> _busMirrors = [
    'https://www.javsee.in',
    'https://www.busjav.cc',
    'https://www.seedmm.in',
    'https://www.javbus.com',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAndParse();
  }

  Map<String, String> get _activeCategories => _currentEngine == '141jav' ? _categories141 : _categoriesBus;

  Dio _getBypassDio() {
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    return dio;
  }

  Future<void> _fetchAndParse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _resources = [];
    });

    try {
      final dio = _getBypassDio();
      final headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15",
        "Accept": "text/html,application/xhtml+xml,application/xml",
        "Cookie": _busCookie ?? "existmag=all; age_verified=1; over18=1",
      };

      List<Map<String, String>> parsedData = [];
      String? currentMirror;

      if (_currentEngine == '141jav') {
        final response = await dio.get('https://www.141jav.com/$_currentCategory', options: Options(headers: headers, validateStatus: (s) => true));
        _parse141(response.data, parsedData);
      } else {
        bool intercepted = false;
        for (String mirror in _busMirrors) {
          currentMirror = mirror;
          final targetUrl = '$mirror/$_currentCategory';
          final response = await dio.get(targetUrl, options: Options(headers: headers, validateStatus: (s) => true));
          
          var doc = html_parser.parse(response.data);
          String title = doc.querySelector('title')?.text.trim() ?? '';

          if (title.contains('Verification') || title.contains('检测') || title.contains('验证')) {
            intercepted = true;
            break;
          }

          var boxes = doc.querySelectorAll('.movie-box');
          if (boxes.isNotEmpty) {
            _parseBusHtml(response.data, parsedData, mirror);
            break;
          }
        }
        if (intercepted) {
          _showWebKitTask(currentMirror!, isList: true);
          return;
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            _errorMessage = "未能提取到资源，请点击右上角刷新。";
          } else {
            _resources = parsedData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_currentEngine == 'javbus') {
        _showWebKitTask('${_busMirrors.last}/$_currentCategory', isList: true);
      } else {
        if (mounted) setState(() { _errorMessage = "连接异常: $e"; _isLoading = false; });
      }
    }
  }

  void _parse141(dynamic html, List<Map<String, String>> data) {
    var document = html_parser.parse(html);
    var allImages = document.querySelectorAll('.image, .thumbnail img');
    for (var img in allImages) {
      String poster = img.attributes['src'] ?? '';
      if (poster.isEmpty || poster.contains('avatar') || poster.contains('logo') || poster.contains('icon')) continue;
      if (poster.startsWith('//')) poster = 'https:$poster';
      else if (poster.startsWith('/')) poster = 'https://www.141jav.com$poster';

      var container = img.parent;
      int depth = 0;
      while (container != null && depth < 6) {
        String targetHref = container.localName == 'a' && (container.attributes['href']?.startsWith('/torrent/') ?? false)
            ? container.attributes['href']!
            : container.querySelector('a[href^="/torrent/"]')?.attributes['href'] ?? '';

        if (targetHref.isNotEmpty && targetHref.length > 9) {
          String code = targetHref.split('/').last.split('?').first;
          String torrentUrl = 'https://www.141jav.com/download/$code.torrent';
          var titleNode = container.querySelector('.title, .subtitle, .thumbnail-text, h1, h2, h3, h4, h5');
          String title = titleNode?.text.trim().replaceAll('\n', ' ') ?? "📦 $code";
          data.add({'title': title, 'poster': poster, 'url': torrentUrl, 'engine': '141jav', 'code': code});
          break;
        }
        container = container.parent;
        depth++;
      }
    }
  }

  void _parseBusHtml(String html, List<Map<String, String>> data, String mirror) {
    var document = html_parser.parse(html);
    var boxes = document.querySelectorAll('.movie-box');
    for (var box in boxes) {
      String detailUrl = box.attributes['href'] ?? '';
      var imgNode = box.querySelector('img');
      String poster = imgNode?.attributes['src'] ?? '';
      String title = imgNode?.attributes['title'] ?? '';
      if (poster.startsWith('//')) poster = 'https:$poster';
      else if (poster.startsWith('/')) poster = '$mirror$poster';
      var dateSpans = box.querySelectorAll('date');
      String code = dateSpans.isNotEmpty ? dateSpans.first.text : '';
      if (title.isEmpty) title = code;
      if (detailUrl.isNotEmpty && poster.isNotEmpty) {
        data.add({'title': "[$code] $title", 'poster': poster, 'url': detailUrl, 'engine': 'javbus', 'code': code});
      }
    }
  }

  void _showWebKitTask(String url, {required bool isList}) {
    final WebViewController controller = WebViewController();
    bool taskCompleted = false;

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String loadedUrl) async {
            if (taskCompleted) return;

            final cookie = await controller.runJavaScriptReturningResult('document.cookie') as String;
            if (cookie.contains('PHPSESSID')) {
              _busCookie = cookie.replaceAll('"', '');
            }

            final title = await controller.getTitle() ?? '';
            if (title.contains('Verification') || title.contains('检测')) return;

            if (isList) {
              Utils.showToast("🔓 验证通过，正在解析列表...");
              final rawHtml = await controller.runJavaScriptReturningResult("document.documentElement.outerHTML");
              String html = "";
              if (rawHtml is String) {
                try { html = jsonDecode(rawHtml) as String; } catch (_) { html = rawHtml; }
              }

              List<Map<String, String>> parsedData = [];
              final uri = Uri.parse(url);
              _parseBusHtml(html, parsedData, '${uri.scheme}://${uri.host}');

              if (mounted) {
                setState(() { _resources = parsedData; _isLoading = false; });
              }
              taskCompleted = true;
              Navigator.pop(context);
            } else {
              Utils.showToast("正利用原生 JS 引擎提取直链...");
              // 🌟 终极直链提取法：直接在拥有合法权限的 WebView 内发动 Fetch 请求！
              final jsCode = '''
                new Promise((resolve, reject) => {
                  if (typeof gid === 'undefined') {
                    resolve('NO_GID');
                    return;
                  }
                  const fetchUrl = `/ajax/uncledatoolsbyajax.php?gid=\${gid}&lang=zh&img=\${img}&uc=\${uc}&floor=\${Math.floor(Math.random() * 1000 + 1)}`;
                  fetch(fetchUrl)
                    .then(r => r.text())
                    .then(html => {
                       const doc = new DOMParser().parseFromString(html, 'text/html');
                       const mag = doc.querySelector('a[href^="magnet:?"]');
                       resolve(mag ? mag.href : 'NO_MAGNET');
                    })
                    .catch(e => resolve('FETCH_ERR'));
                });
              ''';
              final result = await controller.runJavaScriptReturningResult(jsCode);
              String magnet = result.toString().replaceAll('"', '');

              if (magnet.startsWith('magnet:?')) {
                bool success = await ApiService.addTorrent(magnet);
                if (success) Utils.showToast("🎉 极速嗅探成功，已下发！");
                else Utils.showToast("❌ 下发失败，请检查 qB 连接");
              } else {
                Utils.showToast("❌ 提取失败，该番号可能暂无资源");
              }
              taskCompleted = true;
              Navigator.pop(context);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isList ? "正在突破防火墙拉取列表" : "正在提取加密资源...", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black, decoration: TextDecoration.none)),
                  CupertinoButton(padding: EdgeInsets.zero, child: const Text("取消"), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text("由于触发高级防御，已启动原生内核进行截获。如果出现验证码，请手动完成即可。", 
                style: TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.none)),
            ),
            Expanded(child: WebViewWidget(controller: controller)),
          ],
        ),
      ),
    );
  }

  Future<void> _download(Map<String, String> data) async {
    HapticFeedback.mediumImpact();

    if (data['engine'] == '141jav') {
      Utils.showToast("正在发送至下载节点...");
      bool success = await ApiService.addTorrent(data['url']!);
      if (success) Utils.showToast("🎉 已成功下发任务！");
      else Utils.showToast("❌ 下发失败，请检查 qB 连接");
    } else {
      Utils.showToast("启动轻量级请求...");
      try {
        final dio = _getBypassDio();
        final headers = {
          "User-Agent": "Mozilla/5.0",
          "Cookie": _busCookie ?? "existmag=all; age_verified=1; over18=1",
          "Referer": data['url']!,
        };
        final detailResp = await dio.get(data['url']!, options: Options(headers: headers));
        
        // 发现被防爬拦截，直接走强制降级路线
        if (detailResp.data.toString().contains('Verification') || detailResp.data.toString().contains('Just a moment')) {
           throw "Intercepted";
        }

        final gidMatch = RegExp(r'var\s+gid\s*=\s*(\d+);').firstMatch(detailResp.data);

        if (gidMatch != null) {
          final uri = Uri.parse(data['url']!);
          final ajaxResp = await dio.get(
            '${uri.scheme}://${uri.host}/ajax/uncledatoolsbyajax.php',
            queryParameters: {
              'gid': gidMatch.group(1),
              'lang': 'zh',
              'img': RegExp(r"var\s+img\s*=\s*'([^']+)';").firstMatch(detailResp.data)?.group(1) ?? '',
              'uc': RegExp(r'var\s+uc\s*=\s*(\d+);').firstMatch(detailResp.data)?.group(1) ?? '0',
              'floor': DateTime.now().millisecondsSinceEpoch % 1000 + 1,
            },
            options: Options(headers: headers)
          );
          final ajaxDoc = html_parser.parse(ajaxResp.data);
          var magnets = ajaxDoc.querySelectorAll('a[href^="magnet:?"]');
          if (magnets.isNotEmpty) {
            bool success = await ApiService.addTorrent(magnets.first.attributes['href']!);
            if (success) Utils.showToast("🎉 轻量嗅探成功，已下发！");
            else Utils.showToast("❌ 下发失败，请检查 qB 连接");
            return;
          }
        }
        // 解析不到 GID 或 列表为空，启动强制降级！
        throw "Failed to extract via lightweight request";
      } catch (e) {
        _showWebKitTask(data['url']!, isList: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        const bgColor = Color(0xFF0D0D0D);
        const cardColor = Color(0xFF1C1C1E);

        return CupertinoPageScaffold(
          backgroundColor: bgColor,
          navigationBar: CupertinoNavigationBar(
            middle: const Text("深网探索", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
            backgroundColor: bgColor.withOpacity(0.8),
            previousPageTitle: "返回",
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.refresh, color: Colors.white),
              onPressed: _fetchAndParse,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildEngineControl(),
                _buildCategoryControl(),
                Expanded(
                  child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.destructiveRed, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)
                                  ),
                                ],
                              ),
                            )
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 40),
                            itemCount: _resources.length,
                            itemBuilder: (context, index) => _buildResourceCard(_resources[index], cardColor),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEngineControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<String>(
          backgroundColor: Colors.white10,
          thumbColor: CupertinoColors.activeBlue.withOpacity(0.8),
          groupValue: _currentEngine,
          children: const {
            '141jav': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("141JAV", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            'javbus': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("JavBus", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
          },
          onValueChanged: (v) {
            if (v != null) {
              setState(() { _currentEngine = v; _currentCategory = ''; });
              _fetchAndParse();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<String>(
          backgroundColor: Colors.transparent,
          thumbColor: const Color(0xFF3A3A3C),
          groupValue: _currentCategory,
          children: _activeCategories.map((key, value) => MapEntry(
            key,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            )
          )),
          onValueChanged: (v) {
            if (v != null) {
              setState(() => _currentCategory = v);
              _fetchAndParse();
            }
          },
        ),
      ),
    );
  }

  Widget _buildResourceCard(Map<String, String> data, Color cardColor) {
    final isBus = data['engine'] == 'javbus';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CachedNetworkImage(
            imageUrl: data['poster']!,
            height: isBus ? 200 : 240,
            fit: isBus ? BoxFit.contain : BoxFit.cover,
            alignment: isBus ? Alignment.center : Alignment.topCenter,
            // 🌟 修复图片 403 错误：加入防盗链伪装头
            httpHeaders: const {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
              "Referer": "https://www.javbus.com/"
            },
            placeholder: (context, url) => Container(height: 200, color: Colors.white10, child: const CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Container(height: 200, color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(data['title']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  color: isBus ? CupertinoColors.activeBlue : CupertinoColors.activeOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => _download(data),
                  child: Text(isBus ? "嗅探下载" : "直链下载", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
