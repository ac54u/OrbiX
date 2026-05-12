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

  // 🌟 持久化 Cookie 存储
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

  // JavBus 官方镜像矩阵
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

  Future<void> _fetchAndParse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _resources = [];
    });

    try {
      final dio = Dio();
      final headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15",
        "Accept": "text/html,application/xhtml+xml,application/xml",
        "Cookie": _busCookie ?? "existmag=all; age_verified=1; over18=1",
      };

      List<Map<String, String>> parsedData = [];
      String? currentMirror;

      // ==========================================
      // 引擎 1：141JAV
      // ==========================================
      if (_currentEngine == '141jav') {
        final response = await dio.get('https://www.141jav.com/$_currentCategory', options: Options(headers: headers, validateStatus: (s) => true));
        _parse141(response.data, parsedData);
      }
      // ==========================================
      // 引擎 2：JavBus 自动降级突破
      // ==========================================
      else {
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
            _parseBus(boxes, parsedData, mirror);
            break;
          }
        }
        if (intercepted) {
          _showVerificationGateway(currentMirror!);
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
      if (mounted) setState(() { _errorMessage = "连接异常: $e"; _isLoading = false; });
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

  void _parseBus(dynamic boxes, List<Map<String, String>> data, String mirror) {
    for (var box in boxes) {
      String detailUrl = box.attributes['href'] ?? '';
      var imgNode = box.querySelector('img');
      String poster = imgNode?.attributes['src'] ?? '';
      String title = imgNode?.attributes['title'] ?? '';
      if (poster.startsWith('//')) poster = 'https:$poster';
      else if (poster.startsWith('/')) poster = 'https://www.javbus.com$poster';
      var dateSpans = box.querySelectorAll('date');
      String code = dateSpans.isNotEmpty ? dateSpans.first.text : '';
      if (detailUrl.isNotEmpty && poster.isNotEmpty) {
        data.add({'title': title, 'poster': poster, 'url': detailUrl, 'engine': 'javbus', 'code': code});
      }
    }
  }

  void _showVerificationGateway(String url) {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            final cookie = await controller.runJavaScriptReturningResult('document.cookie') as String;
            if (cookie.contains('PHPSESSID')) {
              _busCookie = cookie.replaceAll('"', '');
            }
            final title = await controller.getTitle();
            if (title != null && !title.contains('Verification') && !title.contains('检测')) {
              Utils.showToast("🔓 验证通过");
              Navigator.pop(context);
              _fetchAndParse();
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
                  const Text("安全验证", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black, decoration: TextDecoration.none)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text("取消"),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
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
      Utils.showToast("正在下发任务...");
      bool success = await ApiService.addTorrent(data['url']!);
      if (success) Utils.showToast("🎉 下载任务已添加");
    } else {
      Utils.showToast("正在深度嗅探...");
      try {
        final headers = {
          "User-Agent": "Mozilla/5.0",
          "Cookie": _busCookie ?? "existmag=all; age_verified=1; over18=1",
          "Referer": data['url']!,
        };
        final detailResp = await Dio().get(data['url']!, options: Options(headers: headers));
        final gidMatch = RegExp(r'var\s+gid\s*=\s*(\d+);').firstMatch(detailResp.data);
        if (gidMatch != null) {
          final uri = Uri.parse(data['url']!);
          final ajaxResp = await Dio().get(
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
            if (success) Utils.showToast("🎉 嗅探成功，已下发");
            return;
          }
        }
        Utils.showToast("❌ 嗅探失败");
      } catch (e) {
        Utils.showToast("❌ 异常: $e");
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
                        ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white54)))
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
            placeholder: (context, url) => Container(height: 200, color: Colors.white10),
            errorWidget: (context, url, error) => const Icon(CupertinoIcons.photo, color: Colors.grey),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  color: isBus ? CupertinoColors.activeBlue : CupertinoColors.activeOrange,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => _download(data),
                  child: Text(isBus ? "嗅探" : "下载", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}