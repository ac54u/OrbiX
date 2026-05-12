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
      // 🌟 强化请求头，尽可能伪装成真实的 Safari
      final response = await Dio().get(
        'https://www.141jav.com/',
        options: Options(
          headers: {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh-Hans;q=0.9",
          },
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode != 200) {
        throw "网络访问受限 (HTTP ${response.statusCode})";
      }

      var document = html_parser.parse(response.data);

      // 🌟 获取网页真实的 Title，用来侦测是否被 Cloudflare 拦截
      String pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';

      if (pageTitle.toLowerCase().contains('cloudflare') || pageTitle.toLowerCase().contains('just a moment')) {
        throw "遭遇 Cloudflare 5秒盾拦截，纯接口无法绕过。";
      }

      var magnetLinks = document.querySelectorAll('a[href^="magnet:?"]');
      List<Map<String, String>> parsedData = [];

      for (var link in magnetLinks) {
        var container = link.parent;
        int depth = 0;
        while (container != null && depth < 5) {
          if (container.localName == 'div' || container.localName == 'article' || container.localName == 'li') {
            break;
          }
          container = container.parent;
          depth++;
        }

        if (container != null) {
          var imgNode = container.querySelector('img');
          var titleNode = container.querySelector('h1, h2, h3, h4, h5, p > a, a[title]');

          String poster = imgNode?.attributes['src'] ?? '';
          if (poster.startsWith('//')) poster = 'https:$poster';

          String title = titleNode?.text.trim() ?? titleNode?.attributes['title'] ?? '未知番号资源';
          String magnet = link.attributes['href'] ?? '';

          if (magnet.isNotEmpty && poster.isNotEmpty && !parsedData.any((e) => e['magnet'] == magnet)) {
            parsedData.add({
              'title': title,
              'poster': poster,
              'magnet': magnet,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            // 🌟 如果啥也没抓到，把网页标题打印出来，方便死得明明白白
            _errorMessage = "未找到磁力链接。\n抓取到的网页标题是: [$pageTitle]";
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

  void _download(String magnetUrl) async {
    HapticFeedback.mediumImpact();
    Utils.showToast("正在发送至下载节点...");
    bool success = await ApiService.addTorrent(magnetUrl);
    if (success) {
      Utils.showToast("🎉 已成功添加至 qBittorrent");
    } else {
      Utils.showToast("❌ 添加失败，请检查连接");
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
                              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)
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
            height: 220,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(height: 220, color: Colors.white10, child: const CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => Container(height: 220, color: Colors.white10, child: const Icon(CupertinoIcons.photo, color: Colors.grey)),
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