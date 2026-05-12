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
      String pageTitle = document.querySelector('title')?.text.trim() ?? '无标题';

      if (pageTitle.toLowerCase().contains('cloudflare') || pageTitle.toLowerCase().contains('just a moment')) {
        throw "遭遇 Cloudflare 5秒盾拦截，请稍后再试。";
      }

      List<Map<String, String>> parsedData = [];

      // 🌟 终极万能嗅探法：以海报图片为基准，逆推寻找外层卡片容器
      var allImages = document.querySelectorAll('img');

      for (var img in allImages) {
        String poster = img.attributes['src'] ?? '';
        // 过滤掉头像、Logo 等干扰图片
        if (poster.isEmpty || poster.contains('avatar') || poster.contains('logo') || poster.contains('icon')) continue;

        // 补全图片绝对路径
        if (poster.startsWith('//')) {
          poster = 'https:$poster';
        } else if (poster.startsWith('/')) {
          poster = 'https://www.141jav.com$poster';
        }

        var container = img.parent;
        int depth = 0;
        bool found = false;

        // 向外层遍历 7 层 DOM 树，寻找包含该海报的“卡片”盒子
        while (container != null && depth < 7) {
          // 在这个盒子里寻找所有的 <a> 链接
          var links = container.querySelectorAll('a');
          for (var link in links) {
            String href = link.attributes['href'] ?? '';
            // 只要链接里带有 magnet, .torrent, 或者 /torrent/，全部视为目标！
            if (href.startsWith('magnet:') || href.contains('.torrent') || href.contains('/torrent/')) {

              String magnetUrl = href;
              // 如果是相对路径的种子链接，补全域名 (qBittorrent 支持直接添加 http 种子链接)
              if (magnetUrl.startsWith('/')) magnetUrl = 'https://www.141jav.com$magnetUrl';

              // 找标题 (尝试匹配常见的 h1~h5 或者带 title 属性的标签)
              var titleNode = container.querySelector('h1, h2, h3, h4, h5, .title, p > a, a[title]');
              String title = titleNode?.text.trim() ?? titleNode?.attributes['title'] ?? '未知番号';
              // 很多网站标题喜欢放在 a 标签内部，清理掉换行符
              title = title.replaceAll('\n', ' ').trim();
              if (title.isEmpty) title = '未命名资源';

              // 去重加入列表
              if (!parsedData.any((e) => e['magnet'] == magnetUrl)) {
                parsedData.add({
                  'title': title,
                  'poster': poster,
                  'magnet': magnetUrl,
                });
              }
              found = true;
              break;
            }
          }
          if (found) break; // 当前海报匹配成功，跳出寻找外层的循环
          container = container.parent;
          depth++;
        }
      }

      if (mounted) {
        setState(() {
          if (parsedData.isEmpty) {
            // 如果还失败，抓取前 5 个 a 标签的地址打印出来用于终极诊断
            var debugLinks = document.querySelectorAll('a').take(5).map((e) => e.attributes['href']).join('\n');
            _errorMessage = "DOM 解析失败。\n网页标题: [$pageTitle]\n\n调试提取的链接特征:\n$debugLinks";
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
    // qBittorrent 的 add API 原生支持丢进去 magnet 或者 http://.../.torrent 链接
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
                        child: SingleChildScrollView(
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
                        ),
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
            height: 240, // 稍微调高一点适应竖版海报
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