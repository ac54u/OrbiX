import 'dart:io';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';

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

  String _currentCategory = '';

  final Map<String, String> _categories = {
    '': '首页',
    'new': '最新',
    'popular/': '热门',
    'random/': '随机',
  };

  @override
  void initState() {
    super.initState();
    _fetchAndParse();
  }

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
      };

      List<Map<String, String>> parsedData = [];

      final response = await dio.get(
        'https://www.141jav.com/$_currentCategory', 
        options: Options(headers: headers, validateStatus: (s) => true)
      );

      _parse141(response.data, parsedData);

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            _errorMessage = "未能提取到资源，可能是网络被拦截，请点击右上角刷新。";
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
          
          data.add({
            'title': title, 
            'poster': poster, 
            'url': torrentUrl, 
            'code': code.toUpperCase() // 🌟 格式化番号
          });
          break;
        }
        container = container.parent;
        depth++;
      }
    }
  }

  Future<void> _download(Map<String, String> data) async {
    HapticFeedback.mediumImpact();
    Utils.showToast("正在发送至下载节点...");
    
    // 🌟 这里自动把番号加上去作为分类或者标签，可以方便以后整理，目前先传url
    bool success = await ApiService.addTorrent(data['url']!);
    if (success) {
      Utils.showToast("🎉 已成功下发任务！");
    } else {
      Utils.showToast("❌ 下发失败，请检查 qB 连接");
    }
  }

  // 🌟 战术控制面板
  void _showOptions(BuildContext context, Map<String, String> data) {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(data['code'] ?? '资源选项', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        message: Text(data['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _download(data);
            },
            child: const Text('📥 直接下发至 qBittorrent', style: TextStyle(color: CupertinoColors.activeBlue)),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              Utils.showToast("正在探测 Emby 媒体库...");
              // 用番号去 Emby 里查重
              final itemId = await ApiService.checkMovieInEmby('', title: data['code']);
              if (itemId != null) {
                HapticFeedback.heavyImpact();
                Utils.showToast("⚠️ 别下了！你的 Emby 库中已有此影片！");
              } else {
                HapticFeedback.selectionClick();
                Utils.showToast("✅ 库内未查到此番号，可以安全下载");
              }
            },
            child: const Text('🔍 Emby 库内查重探测', style: TextStyle(color: CupertinoColors.systemPurple)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: data['url'] ?? ''));
              Utils.showToast("已复制种子链接");
            },
            child: const Text('📋 复制种子下载直链', style: TextStyle(color: CupertinoColors.activeOrange)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
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

  Widget _buildCategoryControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<String>(
          backgroundColor: Colors.white10,
          thumbColor: const Color(0xFF3A3A3C),
          groupValue: _currentCategory,
          children: _categories.map((key, value) => MapEntry(
            key,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            )
          )),
          onValueChanged: (v) {
            if (v != null) {
              HapticFeedback.selectionClick();
              setState(() => _currentCategory = v);
              _fetchAndParse();
            }
          },
        ),
      ),
    );
  }

  // 🌟 重新设计的沉浸式海报卡片
  Widget _buildResourceCard(Map<String, String> data, Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 底层大尺寸海报
          CachedNetworkImage(
            imageUrl: data['poster']!,
            width: double.infinity,
            height: 280,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(height: 280, color: Colors.white10, child: const CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Container(height: 280, color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.grey)),
          ),
          
          // 黑色渐变遮罩，为了突出文字
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                ),
              ),
            ),
          ),

          // 浮于表面的信息和按钮
          Positioned(
            left: 16, right: 16, bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: CupertinoColors.activeOrange, borderRadius: BorderRadius.circular(4)),
                        child: Text(data['code'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['title']!, 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2), 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  color: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => _showOptions(context, data),
                  child: const Row(
                    children: [
                      Text("获取", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(width: 4),
                      Icon(CupertinoIcons.cloud_download_fill, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}