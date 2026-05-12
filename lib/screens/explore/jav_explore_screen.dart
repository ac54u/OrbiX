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
      final response = await Dio().get(
        'https://www.141jav.com/',
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

      // 🌟 核心重构：不再找 magnet，而是寻找带有番号的详情页链接，直接逆向拼出种子直链！
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
          // 检查当前容器本身或子元素是否是详情页链接
          String containerHref = container.attributes['href'] ?? '';
          String targetHref = '';

          if (container.localName == 'a' && containerHref.startsWith('/torrent/')) {
            targetHref = containerHref;
          } else {
            var link = container.querySelector('a[href^="/torrent/"]');
            if (link != null) targetHref = link.attributes['href'] ?? '';
          }

          if (targetHref.isNotEmpty && targetHref.length > 9) {
            // 提取番号 (例如 /torrent/NSFS477 -> 拿到 NSFS477)
            String code = targetHref.split('/').last.split('?').first;

            // 🎯 降维打击：直接拼接种子下载直链！qB 完全支持解析 .torrent 链接
            String torrentUrl = 'https://www.141jav.com/download/$code.torrent';

            // 提取标题，去掉没用的换行符
            var titleNode = container.querySelector('.title, .subtitle, .thumbnail-text, h1, h2, h3, h4, h5');
            String title = titleNode?.text.trim().replaceAll('\n', ' ') ?? '';
            if (title.isEmpty || title.length < 3) title = "📦 $code (无标题资源)";

            if (!parsedData.any((e) => e['magnet'] == torrentUrl)) {
              parsedData.add({
                'title': title,
                'poster': poster,
                'magnet': torrentUrl, // 这里依然用 magnet 做 key 名，但实际存的是 .torrent 地址
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
    // 无论是 magnet 还是 .torrent 链接，都可以直接推给 qBittorrent 的 add 接口
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
              onPressed: _fetchAndParse,
            ),
          ),
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
                        )
                      )
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 100, bottom: 40),
                      itemCount: _resources.length,
                      itemBuilder: (context, index) => _buildResourceCard(_resources[index], cardColor),
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