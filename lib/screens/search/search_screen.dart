import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import 'movie_detail_screen.dart';
import 'radarr_movie_detail_screen.dart'; 
import 'interactive_search_screen.dart'; // 🌟 引入刚写好的交互式搜索页

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
  
  // 0: Prowlarr (搜种子), 1: Radarr (搜电影)
  int _searchMode = 0; 

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
      if (_searchMode == 0) {
        // --- Prowlarr 搜种子模式 ---
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

        processed.sort((a, b) => (int.tryParse(b['seeders'].toString()) ?? 0).compareTo(int.tryParse(a['seeders'].toString()) ?? 0));
        if (mounted) setState(() => _results = processed);

      } else {
        // --- Radarr 搜电影模式 ---
        final radarrResults = await ApiService.searchRadarr(_searchCtrl.text);
        if (mounted) setState(() => _results = radarrResults);
      }
    } catch (e) {
      Utils.showToast(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDownloadUrl(dynamic item) {
    return item['magnetUrl'] ?? item['downloadUrl'] ?? item['guid'] ?? '';
  }

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

  // 🌟 核心修改：接入全新的交互式搜索逻辑
  Future<void> _sendToRadarr(dynamic movie) async {
    HapticFeedback.lightImpact();
    Utils.showToast("正在初始化交互式搜索...");
    
    // 1. 确保电影在 Radarr 库里，并拿到它在 Radarr 内部的 ID
    final movieId = await ApiService.ensureMovieInRadarr(movie);
    
    if (movieId != null) {
      if (!mounted) return;
      // 2. 跳转到我们刚写好的手动挑选卡片页
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => InteractiveSearchScreen(
            movieId: movieId,
            movieTitle: movie['title'] ?? "未知电影",
          ),
        ),
      );
    } else {
      Utils.showToast("❌ Radarr 库同步失败，请检查配置");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text("资源搜索", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            border: null,
            previousPageTitle: "返回",
          ),
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          child: SafeArea(
            child: Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchCtrl,
                    placeholder: _searchMode == 0 ? "搜索种子 (Prowlarr)" : "搜索电影资料 (Radarr)",
                    onSuffixTap: () {
                       _searchCtrl.clear();
                       setState(() => _results = []);
                    },
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                // 引擎切换器
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _searchMode,
                      children: const {
                        0: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Prowlarr (找种子)")),
                        1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Radarr (全自动)")),
                      },
                      onValueChanged: (int? value) {
                        if (value != null) {
                          setState(() {
                            _searchMode = value;
                            _results = []; // 切换模式时清空上一次的结果
                          });
                          _doSearch();
                        }
                      },
                    ),
                  ),
                ),
                
                // 列表区域
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(CupertinoIcons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("输入关键词开始搜刮", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            if (_searchMode == 0) {
                              return _buildProwlarrItem(_results[index], isDark);
                            } else {
                              return _buildRadarrItem(_results[index], isDark);
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 原有的 Prowlarr 种子卡片 UI ---
  Widget _buildProwlarrItem(dynamic item, bool isDark) {
    final downloadUrl = _getDownloadUrl(item);
    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => MovieDetailScreen(item: item))),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: (item['tags'] as List).map<Widget>((t) {
                          bool is4k = t == '4K';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: is4k ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(fontSize: 10, color: is4k ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue, fontWeight: FontWeight.bold),
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
                    Text("${item['seeders'] ?? 0}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF34C759))),
                    const Text("做种", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
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
                        Text("推送给 qB", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryColor)),
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

  // --- Radarr 电影卡片 UI 附带点击跳转 ---
  Widget _buildRadarrItem(dynamic item, bool isDark) {
    // 获取电影海报
    String posterUrl = '';
    if (item['images'] != null && (item['images'] as List).isNotEmpty) {
      final poster = (item['images'] as List).firstWhere((img) => img['coverType'] == 'poster', orElse: () => null);
      if (poster != null) posterUrl = poster['remoteUrl'] ?? '';
    }

    bool isAdded = item['added'] != "0001-01-01T00:00:00Z" && item['added'] != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => RadarrMovieDetailScreen(movie: item),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? kCardColorDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : kMinimalShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 电影海报
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: posterUrl,
                      width: 70,
                      height: 105,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[300], width: 70, height: 105),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[300], width: 70, height: 105, child: const Icon(CupertinoIcons.film)),
                    )
                  : Container(color: Colors.grey[300], width: 70, height: 105, child: const Icon(CupertinoIcons.film)),
            ),
            const SizedBox(width: 12),
            // 电影信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? "未知电影",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item['year'] ?? ''} • TMDB: ${item['tmdbId'] ?? ''}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['overview'] ?? "暂无简介",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isAdded
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: CupertinoColors.activeGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            minSize: 30,
                            onPressed: () => _sendToRadarr(item), // 🌟 即使已在库中，点击也可直接跳转选种子
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(CupertinoIcons.checkmark_alt, size: 16, color: CupertinoColors.activeGreen),
                                SizedBox(width: 4),
                                Text("挑选种子", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CupertinoColors.activeGreen)),
                              ],
                            ),
                          )
                        : CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: const Color(0xFFFF9500).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            minSize: 30,
                            onPressed: () => _sendToRadarr(item),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(CupertinoIcons.search, size: 16, color: Color(0xFFFF9500)),
                                SizedBox(width: 4),
                                Text("挑选种子", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF9500))),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
