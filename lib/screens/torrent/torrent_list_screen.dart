import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'movie_detail_sheet.dart';
import '../../services/tmdb_service.dart';
import '../../services/emby_service.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import '../../services/live_activity_service.dart';

import '../../services/youtube_service.dart';

import 'torrent_detail_screen.dart';
import 'add_torrent_sheet.dart';
import '../../widgets/skeleton_card.dart';
import '../player_screen.dart';

class TorrentListScreen extends StatefulWidget {
  const TorrentListScreen({super.key});

  @override
  State<TorrentListScreen> createState() => _TorrentListScreenState();
}

class _TorrentListScreenState extends State<TorrentListScreen> {
  List<dynamic> _torrents = [];

  final Map<String, Map<String, dynamic>> _tmdbCache = {};
  final Map<String, double> _previousProgress = {};

  bool _isLoggedIn = false;
  Timer? _timer;
  int _refreshRate = 3;
  String _filterStatus = 'all';
  String _filterCategory = 'all';
  String _filterTag = 'all';
  String _sortOption = 'default';

  @override
  void initState() {
    super.initState();
    _loadSettingsAndInit();
  }

  void _loadSettingsAndInit() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _refreshRate = p.getInt('refresh_rate') ?? 3;
      });
    }
    await _initData();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _refreshRate), (_) async {
      final p = await SharedPreferences.getInstance();
      int newRate = p.getInt('refresh_rate') ?? 3;
      if (newRate != _refreshRate) {
        _refreshRate = newRate;
        _startTimer();
        return;
      }

      if (_isLoggedIn) {
        await _fetchTorrents();
      } else {
        await _initData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    bool success = await ApiService.login();
    if (success && mounted) {
      setState(() => _isLoggedIn = true);
      _fetchTorrents();
    }
  }

  void _fetchPostersBackground(List<dynamic> torrents) {
    for (var t in torrents) {
      final hash = t['hash'];
      final rawName = t['name'] ?? '';

      // YouTube 任务不需要去 TMDB 刮削海报
      if (t['is_yt'] == true) continue;

      if (hash == null || rawName.isEmpty) continue;
      if (_tmdbCache.containsKey(hash)) continue;

      _tmdbCache[hash] = {'status': 'loading'};

      final parsed = Utils.cleanFileName(rawName);
      TMDBService.searchMovie(parsed['title'], parsed['year']).then((movieData) {
        if (mounted) {
          setState(() {
            if (movieData != null && movieData['poster_url'].isNotEmpty) {
              _tmdbCache[hash] = movieData;
              _tmdbCache[hash]!['status'] = 'success';
            } else {
              _tmdbCache[hash] = {'status': 'failed'};
            }
          });
        }
      });
    }
  }

  Future<void> _fetchTorrents() async {
    // 1. 抓取原有的 BT 任务
    final btData = await ApiService.getTorrents(
      filter: _filterStatus == 'default' ? 'all' : _filterStatus,
      category: _filterCategory,
      tag: _filterTag,
    ) ?? [];

    // 🌟 2. 从全新的 FastAPI 后端抓取 YouTube 任务 (包含下载中和已完成的)
    final rawYtData = await YouTubeDownloadService.getFiles();

    // 🌟 3. 数据“伪装”：解析后端的 progress, status, thumbnail 映射为 UI 格式
    final ytData = rawYtData.map((task) {
      return {
        'hash': task['id'] ?? 'yt_${task['filename'].hashCode}', 
        'name': task['filename'],
        'progress': task['progress'] ?? 1.0, 
        'state': task['status'] ?? 'completed', 
        'is_yt': true,
        'size': task['size'] ?? 0,
        'poster_url': task['thumbnail'] ?? '', // 挂载 YouTube 官方高清封面图
        // ✅ 这里修复了致命 Bug：将 task['filename'] 改为了 task['url']
        'play_url': task['status'] == 'completed' 
            ? YouTubeDownloadService.getVideoUrl(task['url']) 
            : null
      };
    }).toList();

    // 4. 合并数据
    final List<dynamic> allData = [...btData, ...ytData];

    if (mounted) {
      for (var t in allData) {
        final hash = t['hash'];
        final double progress = (t['progress'] ?? 0.0).toDouble();
        final double? prevProgress = _previousProgress[hash];
        final bool isYt = t['is_yt'] == true;

        if (prevProgress != null && prevProgress < 1.0 && progress >= 1.0) {
          final name = t['name'] ?? '任务';
          HapticFeedback.heavyImpact();
          Utils.showToast("🎉 [$name] 下载完成！");
          if (!isYt) {
            EmbyService.processAndRefresh(t['name']);
          }
          LiveActivityService.stop();
        }

        if (hash != null) {
          _previousProgress[hash] = progress;
        }
      }

      setState(() {
        _torrents = allData;
        _isLoggedIn = true;
      });

      // 只给真实的 BT 任务去后台刮削海报
      _fetchPostersBackground(btData);
    }
  }

  Future<void> _executeAction(String hash, String action) async {
    // 🌟 识别是否是 YouTube 专属的删除操作
    final target = _torrents.firstWhere((e) => e['hash'] == hash, orElse: () => null);
    if (target != null && target['is_yt'] == true) {
      if (action == 'delete' || action == 'deleteWithFiles') {
        bool? confirm = await showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text("确认删除"),
            content: const Text("确定要从服务器彻底删除这个视频吗？"),
            actions: [
              CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(ctx, false)),
              CupertinoDialogAction(isDestructiveAction: true, child: const Text("删除"), onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        );
        if (confirm != true) return;

        // 如果还没下载完，后端其实会删掉临时任务。但保险起见还是用统一的文件删除API
        final targetName = target['state'] == 'completed' ? target['name'] : target['hash'];
        final success = await YouTubeDownloadService.deleteFile(targetName);
        if (success) {
          Utils.showToast("已删除视频");
          _fetchTorrents();
        } else {
          Utils.showToast("删除失败，请检查服务器");
        }
      }
      return;
    }

    if (action == 'delete' || action == 'deleteWithFiles') {
      bool? confirm = await showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("确认删除"),
          content: Text(
            action == 'deleteWithFiles' ? "确定要删除资源和本地文件吗？不可恢复。" : "确定要删除这个任务吗？",
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("取消"),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text("删除"),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    HapticFeedback.mediumImpact();
    String? error;
    switch (action) {
      case 'start': error = await ApiService.controlTorrent(hash, 'start'); break;
      case 'pause': error = await ApiService.controlTorrent(hash, 'stop'); break;
      case 'forceStart': error = await ApiService.controlTorrent(hash, 'setForceStart'); break;
      case 'forceRecheck': error = await ApiService.controlTorrent(hash, 'recheck'); break;
      case 'forceReannounce': error = await ApiService.controlTorrent(hash, 'reannounce'); break;
      case 'delete': error = await ApiService.deleteTorrent(hash, false); break;
      case 'deleteWithFiles': error = await ApiService.deleteTorrent(hash, true); break;
      case 'topPrio':
      case 'bottomPrio':
      case 'increasePrio':
      case 'decreasePrio':
        error = await ApiService.controlTorrent(hash, action);
        break;
      default: return;
    }

    if (error != null) {
      HapticFeedback.heavyImpact();
      Utils.showToast("失败: $error");
    } else {
      Utils.showToast("操作成功");
      _fetchTorrents();

      if (action == 'start' || action == 'forceStart') {
        final name = target != null ? target['name'] : '下载任务';
        LiveActivityService.start(name);
      } else if (action == 'pause' || action == 'delete' || action == 'deleteWithFiles') {
        LiveActivityService.stop();
      }
    }
  }

  Future<void> _handlePlay(dynamic t) async {
    final String rawName = t['name'] ?? '';
    final String hash = t['hash'] ?? '';
    final double progress = (t['progress'] ?? 0.0).toDouble();
    final bool isYt = t['is_yt'] == true;

    if (rawName.isEmpty) return;

    // 🌟 YouTube 任务拦截：必须 completed 才能播放
    if (isYt && t['state'] != 'completed') {
      Utils.showToast("视频正在处理中，暂无法播放...");
      return;
    }

    if (!isYt && progress < 0.01) {
      Utils.showToast("缓冲中，请等待下载进度上升后再试");
      return;
    }

    final tmdbData = _tmdbCache[hash];
    final String displayTitle = (!isYt && tmdbData != null && tmdbData['status'] == 'success')
        ? (tmdbData['title'] ?? rawName)
        : rawName;

    Utils.showToast("⚡ 正在建立视频通道...");

    // 🌟 核心播放逻辑分离：YouTube 取自带直链，BT 去解析物理推流
    String? streamUrl;
    if (isYt) {
      streamUrl = t['play_url']; 
    } else {
      streamUrl = await ApiService.getDirectStreamUrl(rawName);
    }

    if (streamUrl != null && mounted) {
      if (!isYt) {
        EmbyService.processAndRefresh(rawName).catchError((_) => false);
      }

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => PlayerScreen(
            streamUrl: streamUrl!,
            title: displayTitle,
          ),
        ),
      );
    } else {
      Utils.showToast("❌ 无法获取播放链接");
    }
  }

  List<dynamic> _processTorrents() {
    List<dynamic> list = List.from(_torrents);
    if (_sortOption != 'default') {
      list.sort((a, b) {
        switch (_sortOption) {
          case 'name':
            return (a['name'] ?? '').compareTo(b['name'] ?? '');
          case 'size':
            return (b['size'] ?? 0).compareTo(a['size'] ?? 0);
          case 'progress':
            return (b['progress'] ?? 0).compareTo(a['progress'] ?? 0);
          case 'added_on':
            return (b['added_on'] ?? 0).compareTo(a['added_on'] ?? 0);
          default:
            return 0;
        }
      });
    }
    return list;
  }

  void _showFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => FilterSheet(
        currentStatus: _filterStatus,
        currentSort: _sortOption,
        currentCategory: _filterCategory,
        currentTag: _filterTag,
        onApply: (status, sort, cat, tag) {
          setState(() {
            _filterStatus = status;
            _sortOption = sort;
            _filterCategory = cat;
            _filterTag = tag;
          });
          _fetchTorrents();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const AddTorrentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _processTorrents();

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(
                  "我的下载",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                backgroundColor: isDark ? kBgColorDark : kBgColorLight,
                border: null,
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showFilterSheet,
                  child: const Icon(
                    CupertinoIcons.line_horizontal_3_decrease_circle,
                    size: 24,
                  ),
                ),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.add_circled_solid, size: 28),
                  onPressed: () => _showAddSheet(context),
                ),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await _fetchTorrents();
                  return Future.delayed(const Duration(milliseconds: 500));
                },
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: (!_isLoggedIn && displayList.isEmpty)
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => SkeletonCard(isDark: isDark, isGrid: false),
                          childCount: 5,
                        ),
                      )
                    : displayList.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 150),
                                child: Column(
                                  children: [
                                    const Icon(CupertinoIcons.tray, size: 48, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text("列表空空如也", style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildTorrentItem(displayList[index], isDark),
                              childCount: displayList.length,
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTorrentItem(dynamic t, bool isDark) {
    final hash = t['hash'] ?? '';
    final state = t['state'] ?? 'unknown';
    final bool isYt = t['is_yt'] == true; 

    bool isStopped =
        state.toLowerCase().contains('paused') ||
        state.toLowerCase().contains('stop') ||
        state.toLowerCase().contains('error') ||
        state == '已暂停';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoContextMenu(
        actions: [
          // YouTube 任务屏蔽 qBittorrent 专属的启停操作
          if (!isYt) ...[
            CupertinoContextMenuAction(
              trailingIcon: isStopped ? CupertinoIcons.play_arrow_solid : CupertinoIcons.pause_fill,
              child: Text(isStopped ? "启动" : "暂停"),
              onPressed: () {
                Navigator.pop(context);
                if (Utils.isValidHash(hash)) {
                  _executeAction(hash, isStopped ? 'start' : 'pause');
                }
              },
            ),
            CupertinoContextMenuAction(
              trailingIcon: CupertinoIcons.bolt_fill,
              child: const Text("强制启动"),
              onPressed: () {
                Navigator.pop(context);
                _executeAction(hash, 'forceStart');
              },
            ),
            CupertinoContextMenuAction(
              trailingIcon: CupertinoIcons.arrow_2_circlepath,
              child: const Text("强制校验"),
              onPressed: () {
                Navigator.pop(context);
                _executeAction(hash, 'forceRecheck');
              },
            ),
            Container(height: 1, color: CupertinoColors.systemGrey5),
            CupertinoContextMenuAction(
              trailingIcon: CupertinoIcons.wand_rays,
              child: const Text("手动整理与入库"),
              onPressed: () {
                Navigator.pop(context);
                final name = t['name'] ?? '';
                if (name.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  Utils.showToast("已发送整理指令: $name");
                  EmbyService.processAndRefresh(name);
                }
              },
            ),
            CupertinoContextMenuAction(
              trailingIcon: CupertinoIcons.wand_stars,
              child: const Text("DeepSeek AI 翻译"),
              onPressed: () async {
                Navigator.pop(context);
                final name = t['name'] ?? '';
                if (name.isNotEmpty) {
                  HapticFeedback.selectionClick();
                  Utils.showToast("🚀 已请求 DeepSeek 翻译，请耐心等待...");

                  final success = await ApiService.requestTranslation(name);
                  if (success) {
                    Utils.showToast("✅ 后端已开始处理，稍后播放即可加载中文字幕");
                  } else {
                    Utils.showToast("❌ 翻译请求失败，请检查后端状态");
                  }
                }
              },
            ),
            Container(height: 1, color: CupertinoColors.systemGrey5),
          ],

          CupertinoContextMenuAction(
            isDestructiveAction: true,
            trailingIcon: CupertinoIcons.trash,
            child: Text(isYt ? "删除视频" : "删除任务"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'delete');
            },
          ),
          if (!isYt)
            CupertinoContextMenuAction(
              isDestructiveAction: true,
              trailingIcon: CupertinoIcons.trash_fill,
              child: const Text("删除任务和文件"),
              onPressed: () {
                Navigator.pop(context);
                _executeAction(hash, 'deleteWithFiles');
              },
            ),
        ],
        child: GestureDetector(
          onDoubleTap: () async {
            if (isYt) return; 

            final rawName = t['name'] ?? '';
            if (rawName.isEmpty) return;

            HapticFeedback.selectionClick();
            Utils.showToast("获取影视信息中...");

            final parsed = Utils.cleanFileName(rawName);
            final cleanTitle = parsed['title'];
            final cleanYear = parsed['year'];
            final quality = parsed['quality'];

            final movieData = await TMDBService.searchMovie(cleanTitle, cleanYear);

            if (movieData != null && mounted) {
              HapticFeedback.lightImpact();
              showCupertinoModalPopup(
                context: context,
                builder: (context) => RadarrStyleMovieSheet(
                  title: movieData['title'],
                  year: movieData['release_date'].toString().length >= 4
                      ? movieData['release_date'].toString().substring(0, 4)
                      : (cleanYear ?? ''),
                  overview: movieData['overview'],
                  posterUrl: movieData['poster_url'],
                  backdropUrl: movieData['backdrop_url'],
                  voteAverage: movieData['vote_average'],
                  quality: quality,
                ),
              );
            } else {
              Utils.showToast("未匹配到相关影视元数据");
            }
          },
          onTap: () {
            if (isYt) {
               _handlePlay(t); 
            } else {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => TorrentDetailScreen(
                    torrent: t,
                    movieData: _tmdbCache[hash]?['status'] == 'success' ? _tmdbCache[hash] : null,
                  ),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Slidable(
              key: ValueKey(hash),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.5,
                children: [
                  SlidableAction(
                    onPressed: (ctx) => _handlePlay(t),
                    backgroundColor: CupertinoColors.activeBlue,
                    foregroundColor: Colors.white,
                    icon: CupertinoIcons.play_rectangle_fill,
                    label: '播放',
                  ),
                  SlidableAction(
                    onPressed: (ctx) => _executeAction(hash, 'delete'),
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    icon: CupertinoIcons.delete,
                    label: '删除',
                  ),
                ],
              ),
              child: _buildTorrentCard(t, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTorrentCard(dynamic t, bool isDark) {
    final double progress = (t['progress'] ?? 0.0).toDouble();
    final String stateRaw = t['state'] ?? 'unknown';
    final int dlSpeed = t['dlspeed'] ?? 0;
    final int upSpeed = t['upspeed'] ?? 0;
    final int eta = t['eta'] ?? 8640000;
    final String hash = t['hash'] ?? '';

    final String rawName = t['name'] ?? '';
    final int totalSize = t['size'] ?? 0;
    final bool isYt = t['is_yt'] == true;

    final stateConfig = _getStateConfig(stateRaw);
    final String stateText = stateConfig['text'];
    final Color stateColor = stateConfig['color'];
    final String etaStr = (eta > 8000000 || eta < 0) ? "∞" : "${eta ~/ 60}m ${eta % 60}s";

    final String sizeStr = Utils.formatBytes(totalSize);
    String quality = Utils.cleanFileName(rawName)['quality'] ?? 'HD';

    final String rawNameUpper = rawName.toUpperCase();
    final bool is4K = rawNameUpper.contains('4K') || rawNameUpper.contains('2160P');

    if (is4K && (quality.toUpperCase() == '4K' || quality.toUpperCase() == '2160P')) {
      quality = '';
    }

    final tmdbData = _tmdbCache[hash];
    final bool hasTmdbPoster = !isYt && tmdbData != null && tmdbData['status'] == 'success';
    final String ytPosterUrl = t['poster_url'] ?? '';
    final bool hasPoster = hasTmdbPoster || (isYt && ytPosterUrl.isNotEmpty);
    final String posterUrl = isYt ? ytPosterUrl : (hasTmdbPoster ? (tmdbData?['poster_url'] ?? '') : '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : kCardColorLight,
        boxShadow: kMinimalShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPoster && posterUrl.isNotEmpty) ...[
            SizedBox(
              width: isYt ? 90 : 76,
              height: isYt ? 60 : 114,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 1.2,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          foregroundDecoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                          ),
                          child: Image.network(
                            posterUrl,
                            fit: BoxFit.cover,
                            headers: const {
                              "Referer": "https://javbee.co/",
                              "User-Agent": "Mozilla/5.0",
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.5)
                                : Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        headers: const {
                          "Referer": "https://javbee.co/",
                          "User-Agent": "Mozilla/5.0",
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.film, color: Colors.grey, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hasTmdbPoster ? (tmdbData?['title'] ?? rawName) : rawName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.2,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stateText,
                        style: TextStyle(color: stateColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isYt)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(CupertinoIcons.play_rectangle_fill, color: Colors.red, size: 10),
                              SizedBox(width: 3),
                              Text('YouTube', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                      if (hasTmdbPoster)
                        Text(
                          "${tmdbData?['release_date']?.toString().split('-').first ?? ''} • ⭐️ ${tmdbData?['vote_average'] ?? ''}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),

                      if (!isYt || totalSize > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(sizeStr, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54)),
                        ),

                      if (is4K && !isYt)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('4K HDR', style: TextStyle(fontSize: 10, color: Color(0xFFFF3B30), fontWeight: FontWeight.w800)),
                        ),

                      if (quality.isNotEmpty && !isYt)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(quality, style: const TextStyle(fontSize: 10, color: CupertinoColors.activeBlue, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}%",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stateColor),
                    ),
                    Text(
                      dlSpeed > 0 || upSpeed > 0 ? "${Utils.formatBytes(dlSpeed > 0 ? dlSpeed : upSpeed)}/s" : "",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFF2F2F7),
                    color: isYt ? Colors.red : stateColor,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isYt ? CupertinoIcons.cloud_download_fill : CupertinoIcons.chart_bar_alt_fill,
                             size: 14,
                             color: isYt ? Colors.red : const Color(0xFFFF9500)),
                        const SizedBox(width: 4),
                        Text(isYt ? 'VideoDL API' : (t['ratio'] ?? 0).toStringAsFixed(2), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(isYt ? '---' : etaStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStateConfig(String state) {
    switch (state) {
      case 'processing':
      case 'downloading':
      case 'stalledDL':
        return {'text': '下载中', 'color': kPrimaryColor};
      case 'uploading':
      case 'stalledUP':
        return {'text': '做种中', 'color': const Color(0xFF34C759)};
      case 'pausedDL':
      case 'pausedUP':
      case 'stoppedDL':
      case 'stoppedUP':
        return {'text': '已暂停', 'color': const Color(0xFFFF9500)};
      case 'failed':
      case 'error':
      case 'missingFiles':
        return {'text': '错误', 'color': const Color(0xFFFF3B30)};
      case 'completed':
        return {'text': '已完成', 'color': const Color(0xFF34C759)};
      default:
        return {'text': state, 'color': Colors.grey};
    }
  }
}

class FilterSheet extends StatefulWidget {
  final String currentStatus;
  final String currentSort;
  final String currentCategory;
  final String currentTag;
  final Function(String, String, String, String) onApply;

  const FilterSheet({
    super.key,
    required this.currentStatus,
    required this.currentSort,
    required this.currentCategory,
    required this.currentTag,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String _status;
  late String _sort;
  late String _category;
  late String _tag;
  int _tabIndex = 0;
  bool _isLoading = true;

  Map<String, String> _categories = {'all': '全部分类'};
  List<String> _tags = ['all'];

  final Map<String, String> _statusMap = {
    'all': '全部状态',
    'downloading': '下载中',
    'seeding': '做种中',
    'completed': '已完成',
    'paused': '已暂停',
    'active': '活跃',
    'inactive': '非活跃',
  };

  final Map<String, String> _sortMap = {
    'default': '默认',
    'name': '名称',
    'size': '大小',
    'progress': '进度',
    'added_on': '添加时间',
  };

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
    _sort = widget.currentSort;
    _category = widget.currentCategory;
    _tag = widget.currentTag;
    _fetchMeta();
  }

  Future<void> _fetchMeta() async {
    final cats = await ApiService.getCategories();
    final ts = await ApiService.getTags();

    if (mounted) {
      setState(() {
        _categories = {'all': '全部分类'};
        cats.forEach((k, v) => _categories[k] = k);
        _tags = ['all', ...ts];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return Container(
          height: 600,
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "筛选与排序",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              CupertinoSegmentedControl<int>(
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("状态"),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("分类"),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("标签"),
                  ),
                  3: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("排序"),
                  ),
                },
                onValueChanged: (v) => setState(() => _tabIndex = v),
                groupValue: _tabIndex,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _buildList(isDark),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      child: const Text("应用"),
                      onPressed: () =>
                          widget.onApply(_status, _sort, _category, _tag),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(bool isDark) {
    switch (_tabIndex) {
      case 0:
        return ListView(
          children: _statusMap.entries
              .map(
                (e) => _buildOption(
                  e.key,
                  e.value,
                  _status == e.key,
                  (k) => setState(() => _status = k),
                  isDark,
                ),
              )
              .toList(),
        );
      case 1:
        return ListView(
          children: _categories.entries
              .map(
                (e) => _buildOption(
                  e.key,
                  e.value,
                  _category == e.key,
                  (k) => setState(() => _category = k),
                  isDark,
                ),
              )
              .toList(),
        );
      case 2:
        return ListView(
          children: _tags
              .map(
                (t) => _buildOption(
                  t,
                  t == 'all' ? '全部标签' : t,
                  _tag == t,
                  (k) => setState(() => _tag = k),
                  isDark,
                ),
              )
              .toList(),
        );
      case 3:
        return ListView(
          children: _sortMap.entries
              .map(
                (e) => _buildOption(
                  e.key,
                  e.value,
                  _sort == e.key,
                  (k) => setState(() => _sort = k),
                  isDark,
                ),
              )
              .toList(),
        );
      default:
        return Container();
    }
  }

  Widget _buildOption(
    String key,
    String label,
    bool selected,
    Function(String) onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => onTap(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFF2F2F7),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selected ? kPrimaryColor : Colors.grey[300],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
