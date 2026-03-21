import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class RadarrMovieDetailScreen extends StatefulWidget {
  final dynamic movie;
  const RadarrMovieDetailScreen({super.key, required this.movie});

  @override
  State<RadarrMovieDetailScreen> createState() => _RadarrMovieDetailScreenState();
}

class _RadarrMovieDetailScreenState extends State<RadarrMovieDetailScreen> {
  bool _isAdding = false;

  // 新增：Emby 状态变量
  String? _embyItemId;
  bool _isCheckingEmby = true;

  @override
  void initState() {
    super.initState();
    _checkEmbyStatus();
  }

  // 新增：自动查询 Emby 状态
  Future<void> _checkEmbyStatus() async {
    final tmdbId = widget.movie['tmdbId']?.toString();
    if (tmdbId != null && tmdbId.isNotEmpty) {
      final itemId = await ApiService.checkMovieInEmby(tmdbId);
      if (mounted) {
        setState(() {
          _embyItemId = itemId;
          _isCheckingEmby = false;
        });
      }
    } else {
      if (mounted) setState(() => _isCheckingEmby = false);
    }
  }

  // 提取图片
  String _getImageUrl(String type) {
    if (widget.movie['images'] != null) {
      final img = (widget.movie['images'] as List).firstWhere(
        (i) => i['coverType'] == type, 
        orElse: () => null
      );
      if (img != null) return img['remoteUrl'] ?? '';
    }
    return '';
  }

  // 格式化时长
  String _formatRuntime(int minutes) {
    if (minutes == 0) return "未知时长";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? "${h}h ${m}m" : "${m}m";
  }

  // 提取评分
  double _getRating() {
    try {
      if (widget.movie['ratings'] != null && widget.movie['ratings']['tmdb'] != null) {
        return (widget.movie['ratings']['tmdb']['value'] as num).toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  Future<void> _addToRadarr() async {
    setState(() => _isAdding = true);
    final success = await ApiService.addMovieToRadarr(widget.movie);
    setState(() => _isAdding = false);
    
    if (success) {
      Utils.showToast("🎬 已成功加入 Radarr！");
      // 更新本地状态，变为已添加
      setState(() {
        widget.movie['added'] = DateTime.now().toIso8601String();
      });
    } else {
      Utils.showToast("❌ 添加失败，可能已存在或配置有误");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final backdrop = _getImageUrl('fanart');
        final poster = _getImageUrl('poster');
        final title = widget.movie['title'] ?? '未知电影';
        final year = widget.movie['year']?.toString() ?? '';
        final overview = widget.movie['overview'] ?? '暂无简介。';
        final runtime = _formatRuntime(widget.movie['runtime'] ?? 0);
        final genres = (widget.movie['genres'] as List?)?.cast<String>() ?? [];
        final rating = _getRating();
        final studio = widget.movie['studio'] ?? '未知发行商';
        final certification = widget.movie['certification'] ?? 'NR';
        
        bool isAdded = widget.movie['added'] != "0001-01-01T00:00:00Z" && widget.movie['added'] != null;

        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text("电影详情", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark.withOpacity(0.8) : kBgColorLight.withOpacity(0.8),
            border: null,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 顶部海报 & 背景图叠加层
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 宽背景图 (Fanart)
                        Container(
                          width: double.infinity,
                          height: 220,
                          color: isDark ? Colors.grey[900] : Colors.grey[300],
                          child: backdrop.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: backdrop,
                                  fit: BoxFit.cover,
                                  colorBlendMode: isDark ? BlendMode.darken : BlendMode.clear,
                                  color: isDark ? Colors.black38 : Colors.transparent,
                                )
                              : const Icon(CupertinoIcons.film, size: 50, color: Colors.grey),
                        ),
                        // 渐变遮罩，让文字更容易看清
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  isDark ? kBgColorDark : kBgColorLight,
                                ],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // 左下角竖版海报
                        Positioned(
                          bottom: -40,
                          left: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 100,
                              height: 150,
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: poster.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
                                  : const Icon(CupertinoIcons.photo),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),

                    // 2. 核心信息区
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 年份、分级、时长
                          Row(
                            children: [
                              Text(year, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(certification, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              Text("•  $runtime", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              if (rating > 0) ...[
                                const Spacer(),
                                const Icon(CupertinoIcons.star_fill, size: 16, color: Color(0xFFFFCC00)),
                                const SizedBox(width: 4),
                                Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),
                              ]
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // 流派标签
                          if (genres.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: genres.map((g) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(g, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                              )).toList(),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                    const SizedBox(height: 24),

                    // 3. 简介与详细资料
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("剧情简介", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 12),
                          Text(
                            overview,
                            style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.grey[400] : Colors.grey[800]),
                          ),
                          const SizedBox(height: 24),
                          
                          // 其他元数据
                          _buildInfoRow("发行商", studio, isDark),
                          _buildInfoRow("TMDB ID", widget.movie['tmdbId']?.toString() ?? '-', isDark),
                          _buildInfoRow("状态", widget.movie['status'] == 'released' ? '已上映' : '未上映', isDark),
                          
                          const SizedBox(height: 40),

                          // 4. 底部大按钮 (已升级为支持 Emby 判断)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: _isCheckingEmby
                                ? const Center(child: CupertinoActivityIndicator()) // 正在查询 Emby 状态
                                : _embyItemId != null
                                    // 状态 1：Emby 里已经有了，高亮绿色播放按钮
                                    ? CupertinoButton(
                                        color: const Color(0xFF52B54B), // Emby 标志性绿色
                                        onPressed: () => ApiService.playInEmby(_embyItemId!),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(CupertinoIcons.play_circle_fill, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text("在 Emby 中播放", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                      )
                                    // 状态 2：Emby 没有，但在 Radarr 库里
                                    : isAdded
                                        ? CupertinoButton(
                                            color: CupertinoColors.activeGreen.withOpacity(0.1),
                                            onPressed: null,
                                            child: const Text("已在 Radarr 库中 (等待下载)", style: TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.activeGreen, fontSize: 14)),
                                          )
                                        // 状态 3：库里也没有，显示下载按钮
                                        : CupertinoButton(
                                            color: const Color(0xFFFF9500),
                                            onPressed: _isAdding ? null : _addToRadarr,
                                            child: _isAdding 
                                              ? const CupertinoActivityIndicator(color: Colors.white)
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: const [
                                                    Icon(CupertinoIcons.cloud_download, color: Colors.white),
                                                    SizedBox(width: 8),
                                                    Text("委托 Radarr 下载", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                                  ],
                                                ),
                                          ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}