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

  // 🌟 新增：JavBus 官方镜像矩阵，用于绕过极高防御的主站
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
        "Cookie": "existmag=all; age_verified=1; over18=1",
      };

      List<Map<String, String>> parsedData = [];
      String pageTitle = "";

      // ==========================================
      // 引擎 1：141JAV 解析逻辑 (保持不变)
      // ==========================================
      if (_currentEngine == '141jav') {
        final response = await dio.get('https://www.141jav.com/$_currentCategory', options: Options(headers: headers, validateStatus: (s) => true));
        if (response.statusCode != 200) throw "141JAV 访问受限 (HTTP ${response.statusCode})";

        var document = html_parser.parse(response.data);
        pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';
        if (pageTitle.toLowerCase().contains('cloudflare') || pageTitle.toLowerCase().contains('just a moment')) {
          throw "141JAV 遭遇防爬虫盾拦截。";
        }

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
      // 引擎 2：JavBus 自动降级突破逻辑
      // ==========================================
      else {
        bool isSuccess = false;

        // 🌟 遍历镜像矩阵，哪个没挂验证码就用哪个！
        for (String mirror in _busMirrors) {
          try {
            final targetUrl = '$mirror/$_currentCategory';
            final response = await dio.get(targetUrl, options: Options(headers: headers, validateStatus: (s) => true));
            if (response.statusCode != 200) continue;

            var document = html_parser.parse(response.data);
            pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';

            // 侦测是否遭遇了验证码或年龄拦截，如果是，直接放弃该节点，测试下一个
            if (pageTitle.toLowerCase().contains('age verification') ||
                pageTitle.toLowerCase().contains('cloudflare') ||
                pageTitle.toLowerCase().contains('just a moment') ||
                pageTitle.toLowerCase().contains('attention required')) {
               print("节点 $mirror 遭遇验证码拦截，正在切换下一个...");
               continue;
            }

            var allBoxes = document.querySelectorAll('.movie-box');
            if (allBoxes.isEmpty) continue; // 如果没抓到数据，也换下一个节点

            for (var box in allBoxes) {
              String detailUrl = box.attributes['href'] ?? '';
              var imgNode = box.querySelector('img');
              String poster = imgNode?.attributes['src'] ?? '';
              String title = imgNode?.attributes['title'] ?? '';

              if (poster.startsWith('//')) {
                poster = 'https:$poster';
              } else if (poster.startsWith('/')) {
                poster = '$mirror$poster'; // 动态使用突破成功的域名拼接图片
              }

              var dateSpans = box.querySelectorAll('date');
              String code = dateSpans.isNotEmpty ? dateSpans.first.text : '';
              if (title.isEmpty) title = code;

              if (detailUrl.isNotEmpty && poster.isNotEmpty) {
                 if (!parsedData.any((e) => e['url'] == detailUrl)) {
                    parsedData.add({
                      'title': "[$code] $title",
                      'poster': poster,
                      'url': detailUrl,
                      'engine': 'javbus'
                    });
                 }
              }
            }

            // 只要有一个节点突围成功，立刻中止遍历！
            isSuccess = true;
            print("🚀 成功突破节点: $mirror");
            break;

          } catch (e) {
            print("节点 $mirror 发生异常: $e");
            continue;
          }
        }

        if (!isSuccess) {
           throw "所有备用线路均被验证码拦截，防线过高，请晚点再试。";
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            _errorMessage = "解析失败：未能提取到资源列表。\n最后的网页标题: [$pageTitle]";
          } else {
            _resources = parsedData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "抓取异常: $e"; _isLoading = false; });
    }
  }

  void _download(Map<String, String> data) async {
    HapticFeedback.mediumImpact();

    if (data['engine'] == '141jav') {
      Utils.showToast("正在发送至下载节点...");
      bool success = await ApiService.addTorrent(data['url']!);
      if (success) Utils.showToast("🎉 已成功下发任务！");
      else Utils.showToast("❌ 下发失败，请检查 qB 连接");
    } else {
      Utils.showToast("正在后台深层嗅探磁力链...");
      try {
        final headers = {
          "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15",
          "Cookie": "existmag=all; age_verified=1; over18=1",
          "Referer": data['url']!,
        };

        final detailResp = await Dio().get(data['url']!, options: Options(headers: headers));

        final gidMatch = RegExp(r'var\s+gid\s*=\s*(\d+);').firstMatch(detailResp.data);
        final ucMatch = RegExp(r'var\s+uc\s*=\s*(\d+);').firstMatch(detailResp.data);
        final imgMatch = RegExp(r"var\s+img\s*=\s*'([^']+)';").firstMatch(detailResp.data);

        if (gidMatch != null) {
          final gid = gidMatch.group(1);
          final uc = ucMatch?.group(1) ?? '0';
          final img = imgMatch?.group(1) ?? '';

          // 🌟 动态提取突围成功的域名，用于发送 Ajax 请求！
          final uri = Uri.parse(data['url']!);
          final ajaxDomain = '${uri.scheme}://${uri.host}';

          final ajaxResp = await Dio().get(
            '$ajaxDomain/ajax/uncledatoolsbyajax.php',
            queryParameters: {
              'gid': gid,
              'lang': 'zh',
              'img': img,
              'uc': uc,
              'floor': DateTime.now().millisecondsSinceEpoch % 1000 + 1,
            },
            options: Options(headers: headers)
          );

          final ajaxDoc = html_parser.parse(ajaxResp.data);
          var magnets = ajaxDoc.querySelectorAll('a[href^="magnet:?"]');

          if (magnets.isNotEmpty) {
            String magnetLink = magnets.first.attributes['href']!;
            Utils.showToast("✅ 嗅探成功，开始下发...");
            bool success = await ApiService.addTorrent(magnetLink);
            if (success) Utils.showToast("🎉 已成功添加至队列！");
            else Utils.showToast("❌ 下发失败，请检查 qB 连接");
            return;
          } else {
            Utils.showToast("❌ 该番号当前暂无磁力分享");
            return;
          }
        }
        Utils.showToast("❌ 嗅探失败：未找到解析参数");
      } catch (e) {
        Utils.showToast("❌ 嗅探网络异常");
        print("Ajax Sniff Error: $e");
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
                            _currentCategory = '';
                          });
                          _fetchAndParse();
                        }
                      },
                    ),
                  ),
                ),

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
            height: isBus ? 200 : 240,
            fit: isBus ? BoxFit.contain : BoxFit.cover,
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
                  color: isBus ? CupertinoColors.activeBlue : CupertinoColors.activeOrange,
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