import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final bool autoPaste;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.autoPaste = true,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _searchCtrl.text = widget.initialQuery!;
        _doSearch();
      } else if (widget.autoPaste) {
        _checkClipboardAndSearch();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardAndSearch() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      String content = data.text!.trim();
      
      // 简单的长度过滤，避免搜索过长的无意义文本
      if (content.length > 50) return; 

      setState(() {
        _searchCtrl.text = content;
      });

      Utils.showToast("已自动填入剪贴板内容");
      _doSearch();
    }
  }

  Future<void> _doSearch() async {
    if (_searchCtrl.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
      _results = [];
    });
    
    try {
      final prowlarrResults = await ApiService.searchProwlarr(_searchCtrl.text);

      final processed = prowlarrResults.map((item) {
        String raw = item['title'].toString().toUpperCase();
        List<String> tags = [];
        
        if (raw.contains('4K') || raw.contains('2160P')) tags.add('4K');
        if (raw.contains('1080P')) tags.add('1080P');
        if (raw.contains('HDR')) tags.add('HDR');
        if (raw.contains('DV') || raw.contains('DOLBY')) tags.add('Dolby');

        return {...item, 'tags': tags};
      }).toList();

      // 排序：做种数倒序
      processed.sort(
        (a, b) => (int.tryParse(b['seeders'].toString()) ?? 0).compareTo(int.tryParse(a['seeders'].toString()) ?? 0),
      );

      if (mounted) setState(() => _results = processed);
    } catch (e) {
      Utils.showToast("搜索失败: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 获取资源的下载链接或磁力链接
  String _getDownloadUrl(dynamic item) {
    return item['magnetUrl'] ?? item['downloadUrl'] ?? item['guid'] ?? '';
  }

  // 核心功能：一键推送到 qBittorrent
  Future<void> _sendToQbittorrent(String url) async {
    if (url.isEmpty) {
      Utils.showToast("未能获取到有效的下载链接");
      return;
    }
    
    Utils.showToast("正在发送至 qBittorrent...");
    final success = await ApiService.addTorrent(url);
    
    if (success) {
      Utils.showToast("🎉 已成功添加到下载队列");
    } else {
      Utils.showToast("❌ 添加失败，请检查服务器连接");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "资源搜索",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            border: null,
            previousPageTitle: "返回",
          ),
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CupertinoSearchTextField(
                    controller: _searchCtrl,
                    placeholder: "搜索电影、剧集 (Prowlarr)",
                    onSuffixTap: () {
                       _searchCtrl.clear();
                       setState(() => _results = []);
                    },
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.search,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "输入关键词开始搜刮",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) =>
                              _buildResultItem(_results[index], isDark),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultItem(dynamic item, bool isDark) {
    final downloadUrl = _getDownloadUrl(item);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => MovieDetailScreen(item: item)),
      ),
      onLongPress: () {
        if (downloadUrl.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: downloadUrl));
          Utils.showToast("链接已复制到剪贴板");
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? kCardColorDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : kMinimalShadow,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? "无标题",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: (item['tags'] as List).map<Widget>((t) {
                          bool is4k = t == '4K';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: is4k ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 10,
                                color: is4k ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${item['indexer'] ?? 'Unknown'} • ${Utils.formatBytes(item['size'] ?? 0)}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${item['seeders'] ?? 0}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34C759),
                      ),
                    ),
                    const Text(
                      "做种",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            
            // 下方操作栏区
            if (downloadUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minSize: 30,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: downloadUrl));
                      Utils.showToast("已复制链接");
                    },
                    child: Row(
                      children: const [
                        Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text("复制", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    minSize: 30,
                    onPressed: () => _sendToQbittorrent(downloadUrl),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.cloud_download, size: 16, color: kPrimaryColor),
                        const SizedBox(width: 4),
                        Text(
                          "下载", 
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.bold, 
                            color: kPrimaryColor
                          )
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}