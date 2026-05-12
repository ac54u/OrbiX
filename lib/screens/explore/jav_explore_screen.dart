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

  // 🌟 双引擎状态管理
  String _currentEngine = '141jav'; // '141jav' 或 'javbus'
  String _currentCategory = '';

  // 🌟 141JAV 的分类
  final Map<String, String> _categories141 = {
    '': '首页',
    'new': '最新',
    'popular/': '热门',
    'random/': '随机',
  };

  // 🌟 JavBus 的分类
  final Map<String, String> _categoriesBus = {
    '': '有码',
    'uncensored': '无码',
    'genre/sub': '中字字幕',
  };

  @override
  void initState() {
    super.initState();
    _fetchAndParse();
  }

  // 获取当前生效的分类字典
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
      };

      List<Map<String, String>> parsedData = [];
      String pageTitle = "";

      // ==========================================
      // 引擎 1：141JAV 解析逻辑
      // ==========================================
      if (_currentEngine == '141jav') {
        final response = await dio.get('https://www.141jav.com/$_currentCategory', options: Options(headers: headers, validateStatus: (s) => true));
        if (response.statusCode != 200) throw "141JAV 访问受限 (HTTP ${response.statusCode})";

        var document = html_parser.parse(response.data);
        pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';
        if (pageTitle.toLowerCase().contains('cloudflare')) throw "141JAV 遭遇 5秒盾拦截。";

        var allImages = document.querySelectorAll('img');
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

              if (!parsedData.any((e) => e['url'] == torrentUrl)) {
                parsedData.add({'title': title, 'poster': poster, 'url': torrentUrl, 'engine': '141jav'});
              }
              break;
            }
            container = container.parent;
            depth++;
          }
        }
      }
      // ==========================================
      // 引擎 2：JavBus 解析逻辑
      // ==========================================
      else {
        final response = await dio.get('https://www.javbus.com/$_currentCategory', options: Options(headers: headers, validateStatus: (s) => true));
        if (response.statusCode != 200) throw "JavBus 访问受限 (HTTP ${response.statusCode})";

        var document = html_parser.parse(response.data);
        pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';

        var allBoxes = document.querySelectorAll('.movie-box');
        for (var box in allBoxes) {
          String detailUrl = box.attributes['href'] ?? '';
          var imgNode = box.querySelector('img');
          String poster = imgNode?.attributes['src'] ?? '';
          String title = imgNode?.attributes['title'] ?? '';

          if (poster.startsWith('//')) poster = 'https:$poster';

          // 提取番号
          var dateSpans = box.querySelectorAll('date');
          String code = dateSpans.isNotEmpty ? dateSpans.first.text : '';
          if (title.isEmpty) title = code;

          if (detailUrl.isNotEmpty && poster.isNotEmpty) {
             if (!parsedData.any((e) => e['url'] == detailUrl)) {
                parsedData.add({
                  'title': "[$code] $title",
                  'poster': poster,
                  'url': detailUrl, // 注意：JavBus 存的是详情页 URL，需要点击下载时二次嗅探
                  'engine': 'javbus'
                });
             }
          }
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            _errorMessage = "解析失败：未能提取到资源列表。\n网页标题: [$pageTitle]";
          } else {
            _resources = parsedData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "抓取失败: $e"; _isLoading = false; });
    }
  }

  // 🌟 核心：下载分流处理
  void _download(Map<String, String> data) async {
    HapticFeedback.mediumImpact();

    if (data['engine'] == '141jav') {
      // 141JAV 直接下发 .torrent 链接
      Utils.showToast("正在发送至下载节点...");
      bool success = await ApiService.addTorrent(data['url']!);
      if (success) Utils.showToast("🎉 已成功下发任务！");
      else Utils.showToast("❌ 下发失败，请检查 qB 连接");
    } else {
      // 🌟 JavBus 动态 Ajax 嗅探逻辑
      Utils.showToast("正在后台深层嗅探磁力链...");
      try {
        final detailResp = await Dio().get(
          data['url']!,
          options: Options(headers: {"User-Agent": "Mozilla/5.0"}),
        );

        // 从 HTML 中提取 Ajax 必须的参数
        final gidMatch = RegExp(r'var gid = (\d+);').firstMatch(detailResp.data);
        final ucMatch = RegExp(r'var uc = (\d+);').firstMatch(detailResp.data);
        final imgMatch = RegExp(r"var img = '([^']+)';").firstMatch(detailResp.data);

        if (gidMatch != null) {
          final gid = gidMatch.group(1);
          final uc = ucMatch?.group(1) ?? '0';
          final img = imgMatch?.group(1) ?? '';

          final ajaxUrl = 'https://www.javbus.com/ajax/uncledatoolsbyajax.php?gid=$gid&lang=zh&img=$img&uc=$uc&floor=123';
          final ajaxResp = await Dio().get(
            ajaxUrl,
            options: Options(headers: {'Referer': data['url']!})
          );

          final ajaxDoc = html_parser.parse(ajaxResp.data);
          var magnets = ajaxDoc.querySelectorAll('a[href^="magnet:?"]');

          if (magnets.isNotEmpty) {
            // 取第一个磁力链（通常是做种数最多的）
            String magnetLink = magnets.first.attributes['href']!;
            Utils.showToast("✅ 嗅探成功，开始下发...");
            bool success = await ApiService.addTorrent(magnetLink);
            if (success) Utils.showToast("🎉 已成功添加至队列！");
            else Utils.showToast("❌ 下发失败，请检查 qB 连接");
            return;
          }
        }
        Utils.showToast("❌ 嗅探失败：该番号可能暂无磁力资源");
      } catch (e) {
        Utils.showToast("❌ 嗅探网络异常: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final bgColor = const Color(0xFF0D0D0D);
        final cardColor = const Color(0xFF1C1C1E);

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
                // 🌟 第 1 层：引擎选择器 (141JAV vs JavBus)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: Colors.white10,
                      thumbColor: CupertinoColors.activeBlue.withOpacity(0.8),
                      groupValue: _currentEngine,
                      children: const {
                        '141jav': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("141JAV (直链)", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                        'javbus': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("JavBus (全网嗅探)", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                      },
                      onValueChanged: (v) {
                        if (v != null && v != _currentEngine) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentEngine = v;
                            _currentCategory = ''; // 切换引擎重置分类
                          });
                          _fetchAndParse();
                        }
                      },
                    ),
                  ),
                ),

                // 🌟 第 2 层：内容分类切换器
                Padding(
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
                        if (v != null && v != _currentCategory) {
                          HapticFeedback.lightImpact();
                          setState(() => _currentCategory = v);
                          _fetchAndParse();
                        }
                      },
                    ),
                  ),
                ),

                // 列表内容区域
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

  Widget _buildResourceCard(Map<String, String> data, Color cardColor) {
    // 动态调整海报显示策略：141jav多为竖版，JavBus多为横版(DVD封面)
    final isBus = data['engine'] == 'javbus';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CachedNetworkImage(
            imageUrl: data['poster']!,
            height: isBus ? 200 : 240, // 横版封面稍微矮一点
            fit: isBus ? BoxFit.contain : BoxFit.cover, // Javbus尽量展示全貌
            alignment: isBus ? Alignment.center : Alignment.topCenter,
            placeholder: (context, url) => Container(height: 200, color: Colors.white10, child: const CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Container(height: 200, color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data['title']!,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isBus ? CupertinoColors.activeBlue : CupertinoColors.activeOrange, // 区分不同引擎的按钮颜色
                  borderRadius: BorderRadius.circular(20),
                  minSize: 32,
                  onPressed: () => _download(data),
                  child: Row(
                    children: [
                      Icon(isBus ? CupertinoIcons.search_circle_fill : CupertinoIcons.cloud_download_fill, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(isBus ? "嗅探下载" : "直下", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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