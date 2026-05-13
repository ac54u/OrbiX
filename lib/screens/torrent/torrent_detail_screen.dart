import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class TorrentDetailScreen extends StatefulWidget {
  final dynamic torrent;
  // 从列表页传过来的刮削数据
  final Map<String, dynamic>? movieData;

  const TorrentDetailScreen({super.key, required this.torrent, this.movieData});

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  int _segIndex = 0;
  List<dynamic> _files = [];
  Map<String, dynamic> _peers = {};
  bool _loading = true;
  Timer? _timer;

  // 记录最新的 torrent 数据，方便迁移路径后页面刷新
  late dynamic _currentTorrent;

  @override
  void initState() {
    super.initState();
    _currentTorrent = widget.torrent;
    _refreshData();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshData() async {
    final hash = _currentTorrent['hash'];

    // 定期刷新基础信息，确保路径和状态是最新的
    final tData = await ApiService.getTorrents(filter: 'all');
    if (tData != null && mounted) {
      final updated = tData.firstWhere((e) => e['hash'] == hash, orElse: () => null);
      if (updated != null) {
        setState(() => _currentTorrent = updated);
      }
    }

    if (_segIndex == 2) {
      final f = await ApiService.getTorrentFiles(hash);
      if (mounted && f != null) setState(() => _files = f);
    } else if (_segIndex == 1) {
      final p = await ApiService.getTorrentPeers(hash);
      if (mounted && p != null) setState(() => _peers = p['peers'] ?? {});
    }
    if (mounted) setState(() => _loading = false);
  }

  // 🚀 核心新增：触发一键打鸡血逻辑
  void _handleInjectTrackers() async {
    HapticFeedback.heavyImpact(); // 强力震动反馈
    
    final hash = _currentTorrent['hash'];
    final bool isPrivate = _currentTorrent['private'] ?? false;

    if (isPrivate) {
      Utils.showToast("⚠️ PT 种子受保护，禁止注入公共 Tracker");
      return;
    }

    Utils.showToast("正在同步全球最新 Tracker...");
    bool success = await ApiService.injectTrackers(hash, isPrivate);
    
    if (success) {
      _refreshData(); // 成功后刷新一次数据
    }
  }

  // 🌟 唤出高级感路径迁移面板
  void _showMoveLocationSheet(String hash, String currentPath, bool isDark) {
    final TextEditingController pathCtrl = TextEditingController(text: currentPath);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : kBgColorLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("迁移文件位置", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              const Text("将此任务的数据移动到服务器上的新文件夹", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: pathCtrl,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(CupertinoIcons.folder, color: Colors.grey, size: 20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  child: const Text("确认迁移", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final newPath = pathCtrl.text.trim();
                    if (newPath.isEmpty || newPath == currentPath) {
                      Navigator.pop(ctx);
                      return;
                    }
                    Navigator.pop(ctx); // 关闭弹窗

                    HapticFeedback.mediumImpact();
                    Utils.showToast("正在发送迁移指令...");

                    final error = await ApiService.setLocation(hash, newPath);
                    if (error == null) {
                       HapticFeedback.lightImpact();
                       Utils.showToast("✅ 迁移已开始");
                       _refreshData(); // 刷新页面数据
                    } else {
                       Utils.showToast("❌ 迁移失败: $error");
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "详情",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            previousPageTitle: "我的下载",
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          ),
          child: Column(
            children: [
              const SizedBox(height: 100), // 为导航栏留出空间
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _segIndex,
                    children: {
                      0: _buildTabItem("概览", 0, isDark),
                      1: _buildTabItem("连接", 1, isDark),
                      2: _buildTabItem("文件", 2, isDark),
                    },
                    onValueChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _segIndex = v;
                          _loading = true;
                        });
                        _refreshData();
                      }
                    },
                    thumbColor: kPrimaryColor,
                    backgroundColor: isDark ? Colors.white10 : CupertinoColors.systemGrey5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildContent(_currentTorrent, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabItem(String text, int index, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: _segIndex == index ? Colors.white : (isDark ? Colors.white : Colors.black),
          fontWeight: _segIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildContent(dynamic t, bool isDark) {
    if (_segIndex == 0) return _buildInfoView(t, isDark);
    if (_segIndex == 1) return _buildPeersView(isDark);
    return _buildFilesView(isDark);
  }

  Widget _buildInfoView(dynamic t, bool isDark) {
    final addedDate = DateTime.fromMillisecondsSinceEpoch(
      (t['added_on'] ?? 0) * 1000,
    );

    final movieData = widget.movieData;
    final savePath = t['save_path'] ?? '/downloads';
    final bool isPrivate = t['private'] ?? false;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 📊 1. 基本信息卡片
        CupertinoListSection.insetGrouped(
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          header: Text("基本信息", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            _row("名称", movieData?['title'] ?? t['name'], isDark, bold: true),
            _row("大小", Utils.formatBytes(t['size'] ?? 0), isDark),
            _row("进度", "${((t['progress'] ?? 0) * 100).toStringAsFixed(1)}%", isDark),
            _row("状态", t['state'] ?? '', isDark),
            _row(
              "添加时间",
              "${addedDate.year}-${addedDate.month}-${addedDate.day} ${addedDate.hour}:${addedDate.minute}",
              isDark,
            ),
          ],
        ),

        // 📁 2. 存储位置与迁移卡片
        CupertinoListSection.insetGrouped(
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          header: Text("存储与路径", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            GestureDetector(
              onTap: () => _showMoveLocationSheet(t['hash'], savePath, isDark),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.transparent, 
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.folder_fill, color: CupertinoColors.activeBlue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("当前位置", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            savePath,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text("迁移", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                          const SizedBox(width: 4),
                          Icon(CupertinoIcons.arrow_right_arrow_left, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 🚀 3. 🌟 核心新增：高级操作卡片 (打鸡血按钮)
        CupertinoListSection.insetGrouped(
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          header: Text("高级操作", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            GestureDetector(
              onTap: _handleInjectTrackers,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPrivate 
                          ? Colors.grey.withOpacity(0.1) 
                          : CupertinoColors.activeGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.bolt_fill, 
                        color: isPrivate ? Colors.grey : CupertinoColors.activeGreen, 
                        size: 22
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "一键打鸡血", 
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.bold, 
                              color: isPrivate ? Colors.grey : (isDark ? Colors.white : Colors.black)
                            )
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPrivate ? "PT 种子禁止添加公共 Tracker" : "从全球同步优质 Tracker 强力加速", 
                            style: const TextStyle(fontSize: 12, color: Colors.grey)
                          ),
                        ],
                      ),
                    ),
                    if (!isPrivate)
                      const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 📉 4. 传输数据卡片
        CupertinoListSection.insetGrouped(
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          header: Text("传输数据", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            _row("下载速度", "${Utils.formatBytes(t['dlspeed'] ?? 0)}/s", isDark),
            _row("已下载", Utils.formatBytes(t['downloaded'] ?? 0), isDark),
            _row("分享率", (t['ratio'] ?? 0).toStringAsFixed(2), isDark),
          ],
        ),
      ],
    );
  }

  // ... 后面部分代码 (PeersView, FilesView, row等) 保持不变 ...

  Widget _buildPeersView(bool isDark) {
    if (_peers.isEmpty) {
      return Center(
        child: Text("暂无连接", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
      );
    }

    final list = _peers.values.toList();
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        return Container(
          color: isDark ? kCardColorDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p['ip'] ?? '?.?.?.?',
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
              ),
              Text(
                "${((p['progress'] ?? 0) * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesView(bool isDark) {
    if (_files.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final f = _files[index];
        return Container(
          color: isDark ? kCardColorDark : Colors.white,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f['name'], style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (f['progress'] ?? 0.0).toDouble(),
                minHeight: 2,
                backgroundColor: isDark ? Colors.white10 : const Color(0xFFF2F2F7),
                color: kPrimaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, bool isDark, {bool bold = false, bool small = false}) {
    return CupertinoListTile(
      backgroundColor: isDark ? kCardColorDark : Colors.white,
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      trailing: SizedBox(
        width: 220,
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: small ? 12 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}