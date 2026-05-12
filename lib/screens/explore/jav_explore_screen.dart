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

  // 🌟 新增：当前选中的分类路由
  String _currentCategory = '';

  // 🌟 定义分类字典
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

  Future<void> _fetchAndParse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _resources = [];
    });

    try {
      // 🌟 根据选中的分类动态拼接 URL
      final targetUrl = 'https://www.141jav.com/$_currentCategory';

      final response = await Dio().get(
        targetUrl,
        options: Options(
          headers: {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml",
          },
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode != 200) {
        throw "网络访问受限 (HTTP ${response.statusCode})";
      }

      var document = html_parser.parse(response.data);
      String pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';

      if (pageTitle.toLowerCase().contains('cloudflare') || pageTitle.toLowerCase().contains('just a moment')) {
        throw "遭遇 Cloudflare 5秒盾拦截，请稍后再试。";
      }

      List<Map<String, String>> parsedData = [];
      var allImages = document.querySelectorAll('img');

      for (var img in allImages) {
        String poster = img.attributes['src'] ?? '';
        if (poster.isEmpty || poster.contains('avatar') || poster.contains('logo') || poster.contains('icon')) continue;

        if (poster.startsWith('//')) {
          poster = 'https:$poster';
        } else if (poster.startsWith('/')) {
          poster = 'https://www.141jav.com$poster';
        }

        var container = img.parent;
        int depth = 0;
        bool found = false;

        while (container != null && depth < 6) {
          String containerHref = container.attributes['href'] ?? '';
          String targetHref = '';

          if (container.localName == 'a' && containerHref.startsWith('/torrent/')) {
            targetHref = containerHref;
          } else {
            var link = container.querySelector('a[href^="/torrent/"]');
            if (link != null) targetHref = link.attributes['href'] ?? '';
          }

          if (targetHref.isNotEmpty && targetHref.length > 9) {
            String code = targetHref.split('/').last.split('?').first;
            String torrentUrl = 'https://www.141jav.com/download/$code.torrent';

            var titleNode = container.querySelector('.title, .subtitle, .thumbnail-text, h1, h2, h3, h4, h5');
            String title = titleNode?.text.trim().replaceAll('\n', ' ') ?? '';
            if (title.isEmpty || title.length < 3) title = "📦 $code (无标题资源)";

            if (!parsedData.any((e) => e['magnet'] == torrentUrl)) {
              parsedData.add({
                'title': title,
                'poster': poster,
                'magnet': torrentUrl,
              });
            }
            found = true;
            break;
          }
          container = container.parent;
          depth++;
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            _errorMessage = "解析失败：未能在页面找到番号链接。\n网页标题: [$pageTitle]";
          } else {
            _resources = parsedData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "抓取失败: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _download(String torrentUrl) async {
    HapticFeedback.mediumImpact();
    Utils.showToast("正在发送至下载节点...");
    bool success = await ApiService.addTorrent(torrentUrl);
    if (success) {
      Utils.showToast("🎉 已成功下发任务！");
    } else {
      Utils.showToast("❌ 下发失败，请检查 qB 连接");
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
              onPressed: _fetchAndParse, // 刷新当前分类
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 🌟 新增：顶部分类切换器
                Padding(
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
                        if (v != null && v != _currentCategory) {
                          HapticFeedback.lightImpact();
                          setState(() => _currentCategory = v);
                          _fetchAndParse(); // 切换后自动拉取新数据
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
            height: 240,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(height: 240, color: Colors.white10, child: const CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Container(height: 240, color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data['title']!,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: CupertinoColors.activeOrange,
                  borderRadius: BorderRadius.circular(20),
                  minSize: 32,
                  onPressed: () => _download(data['magnet']!),
                  child: Row(
                    children: const [
                      Icon(CupertinoIcons.cloud_download_fill, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text("下载", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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