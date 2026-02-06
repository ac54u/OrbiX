import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

// 引入详情页和添加页
import 'torrent_detail_screen.dart';
import 'add_torrent_sheet.dart';

class TorrentListScreen extends StatefulWidget {
  const TorrentListScreen({super.key});

  @override
  State<TorrentListScreen> createState() => _TorrentListScreenState();
}

class _TorrentListScreenState extends State<TorrentListScreen> {
  List<dynamic> _torrents = [];
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

  Future<void> _fetchTorrents() async {
    final data = await ApiService.getTorrents(
      filter: _filterStatus == 'default' ? 'all' : _filterStatus,
      category: _filterCategory,
      tag: _filterTag,
    );

    if (data != null && mounted) {
      setState(() {
        _torrents = data;
        _isLoggedIn = true;
      });
    } else {
      setState(() => _isLoggedIn = false);
    }
  }

  Future<void> _executeAction(String hash, String action) async {
    if (action == 'delete' || action == 'deleteWithFiles') {
      bool? confirm = await showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("确认删除"),
          content: Text(
            action == 'deleteWithFiles' ? "确定要删除种子和本地文件吗？不可恢复。" : "确定要删除这个任务吗？",
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
      case 'start':
        error = await ApiService.controlTorrent(hash, 'start');
        break;
      case 'pause':
        error = await ApiService.controlTorrent(hash, 'stop');
        break;
      case 'forceStart':
        error = await ApiService.controlTorrent(hash, 'setForceStart');
        break;
      case 'forceRecheck':
        error = await ApiService.controlTorrent(hash, 'recheck');
        break;
      case 'forceReannounce':
        error = await ApiService.controlTorrent(hash, 'reannounce');
        break;
      case 'delete':
        error = await ApiService.deleteTorrent(hash, false);
        break;
      case 'deleteWithFiles':
        error = await ApiService.deleteTorrent(hash, true);
        break;
      case 'topPrio':
      case 'bottomPrio':
      case 'increasePrio':
      case 'decreasePrio':
        error = await ApiService.controlTorrent(hash, action);
        break;
      default:
        return;
    }

    if (error != null) {
      HapticFeedback.heavyImpact();
      Utils.showToast("失败: $error");
    } else {
      Utils.showToast("操作成功");
      _fetchTorrents();
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
    
    // 1. 使用 ValueListenableBuilder 监听主题变化
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
                sliver: displayList.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 150),
                            child: Column(
                              children: [
                                const Icon(
                                  CupertinoIcons.tray,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isLoggedIn ? "列表空空如也" : "正在连接服务器...",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          // 2. 将 isDark 传递给子组件
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

  // 接收 isDark 参数
  Widget _buildTorrentItem(dynamic t, bool isDark) {
    final hash = t['hash'] ?? '';
    final state = t['state'] ?? 'unknown';

    bool isStopped =
        state.toLowerCase().contains('paused') ||
        state.toLowerCase().contains('stop') ||
        state.toLowerCase().contains('error') ||
        state == '已暂停';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoContextMenu(
        actions: [
          CupertinoContextMenuAction(
            trailingIcon: isStopped
                ? CupertinoIcons.play_arrow_solid
                : CupertinoIcons.pause_fill,
            child: Text(isStopped ? "启动" : "暂停"),
            onPressed: () {
              Navigator.pop(context);
              if (Utils.isValidHash(hash)) {
                _executeAction(hash, isStopped ? 'start' : 'pause');
              } else {
                Utils.showToast("无效的 Hash ID");
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
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.antenna_radiowaves_left_right,
            child: const Text("强制汇报"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'forceReannounce');
            },
          ),
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.arrow_up_to_line,
            child: const Text("置顶队列"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'topPrio');
            },
          ),
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.arrow_up,
            child: const Text("提高优先级"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'increasePrio');
            },
          ),
          CupertinoContextMenuAction(
            trailingIcon: CupertinoIcons.arrow_down,
            child: const Text("降低优先级"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'decreasePrio');
            },
          ),
          Container(height: 1, color: CupertinoColors.systemGrey5),
          CupertinoContextMenuAction(
            isDestructiveAction: true,
            trailingIcon: CupertinoIcons.trash,
            child: const Text("删除任务"),
            onPressed: () {
              Navigator.pop(context);
              _executeAction(hash, 'delete');
            },
          ),
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
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => TorrentDetailScreen(torrent: t),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Slidable(
              key: ValueKey(hash),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.5,
                children: [
                  if (isStopped)
                    SlidableAction(
                      onPressed: (ctx) => _executeAction(hash, 'start'),
                      backgroundColor: const Color(0xFF34C759),
                      foregroundColor: Colors.white,
                      icon: CupertinoIcons.play_arrow_solid,
                      label: '启动',
                    )
                  else
                    SlidableAction(
                      onPressed: (ctx) => _executeAction(hash, 'pause'),
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      icon: CupertinoIcons.pause_fill,
                      label: '暂停',
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

  // 接收 isDark 参数
  Widget _buildTorrentCard(dynamic t, bool isDark) {
    final double progress = (t['progress'] ?? 0.0).toDouble();
    final String stateRaw = t['state'] ?? 'unknown';
    final int dlSpeed = t['dlspeed'] ?? 0;
    final int upSpeed = t['upspeed'] ?? 0;
    final int eta = t['eta'] ?? 8640000;

    final stateConfig = _getStateConfig(stateRaw);
    final String stateText = stateConfig['text'];
    final Color stateColor = stateConfig['color'];
    final String etaStr = (eta > 8000000 || eta < 0)
        ? "∞"
        : "${eta ~/ 60}m ${eta % 60}s";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : kCardColorLight,
        boxShadow: kMinimalShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t['name'] ?? '无标题',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${(progress * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: stateColor,
                ),
              ),
              Text(
                dlSpeed > 0 || upSpeed > 0
                    ? "${Utils.formatBytes(dlSpeed > 0 ? dlSpeed : upSpeed)}/s"
                    : "",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? Colors.grey[800]
                  : const Color(0xFFF2F2F7),
              color: stateColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    size: 14,
                    color: Color(0xFFFF9500),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (t['ratio'] ?? 0).toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(CupertinoIcons.time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    etaStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStateConfig(String state) {
    switch (state) {
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
      case 'error':
      case 'missingFiles':
        return {'text': '错误', 'color': const Color(0xFFFF3B30)};
      default:
        return {'text': state, 'color': Colors.grey};
    }
  }
}

// --- 筛选面板 (FilterSheet) ---
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
    // 3. FilterSheet 也使用 ValueListenableBuilder 确保弹窗内颜色实时更新
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
                    color: isDark ? Colors.white : Colors.black, // 适配文字颜色
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
                    : _buildList(isDark), // 传递 isDark
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