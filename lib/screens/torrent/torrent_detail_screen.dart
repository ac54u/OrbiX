import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshData();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshData() async {
    final hash = widget.torrent['hash'];
    if (_segIndex == 2) {
      final f = await ApiService.getTorrentFiles(hash);
      if (mounted && f != null) setState(() => _files = f);
    } else if (_segIndex == 1) {
      final p = await ApiService.getTorrentPeers(hash);
      if (mounted && p != null) setState(() => _peers = p['peers'] ?? {});
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.torrent;
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
              Expanded(child: _buildContent(t, isDark)),
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 🎬 海报已按照要求移除，页面直接从信息卡片开始

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
            // 优先显示刮削到的标题，否则显示文件名
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

        // 📉 2. 传输数据卡片
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
