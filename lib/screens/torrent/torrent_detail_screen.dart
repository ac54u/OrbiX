import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class TorrentDetailScreen extends StatefulWidget {
  final dynamic torrent;
  const TorrentDetailScreen({super.key, required this.torrent});

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
    // 1. 监听主题变化
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
              const SizedBox(height: 100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSegmentedControl<int>(
                    children: {
                      0: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text("概览", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text("连接", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ),
                      2: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text("文件", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ),
                    },
                    onValueChanged: (v) {
                      setState(() {
                        _segIndex = v;
                        _loading = true;
                      });
                      _refreshData();
                    },
                    groupValue: _segIndex,
                    borderColor: isDark ? Colors.white54 : kPrimaryColor,
                    selectedColor: kPrimaryColor,
                    pressedColor: kPrimaryColor.withOpacity(0.2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildContent(t, isDark)), // 传递 isDark
            ],
          ),
        );
      },
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        CupertinoListSection.insetGrouped(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          header: Text("基本信息", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            _row("名称", t['name'] ?? '', isDark, bold: true),
            _row("大小", Utils.formatBytes(t['size'] ?? 0), isDark),
            _row("进度", "${((t['progress'] ?? 0) * 100).toStringAsFixed(1)}%", isDark),
            _row("状态", t['state'] ?? '', isDark),
            _row(
              "添加时间",
              "${addedDate.year}-${addedDate.month}-${addedDate.day} ${addedDate.hour}:${addedDate.minute}",
              isDark,
            ),
            _row("保存路径", t['save_path'] ?? '', isDark, small: true),
            _row("分类", t['category'] ?? '无', isDark, small: true),
            _row("标签", t['tags'] ?? '', isDark, small: true),
          ],
        ),
        CupertinoListSection.insetGrouped(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          decoration: BoxDecoration(
            color: isDark ? kCardColorDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          header: Text("传输数据", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          children: [
            _row("下载速度", "${Utils.formatBytes(t['dlspeed'] ?? 0)}/s", isDark),
            _row("上传速度", "${Utils.formatBytes(t['upspeed'] ?? 0)}/s", isDark),
            _row("已下载", Utils.formatBytes(t['downloaded'] ?? 0), isDark),
            _row("已上传", Utils.formatBytes(t['uploaded'] ?? 0), isDark),
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
      padding: const EdgeInsets.only(top: 0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final ip = p['ip'] ?? '?.?.?.?';
        return Container(
          color: isDark ? kCardColorDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ip,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    "${((p['progress'] ?? 0) * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesView(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final f = _files[index];
        final progress = (f['progress'] ?? 0.0).toDouble();

        return Container(
          color: isDark ? kCardColorDark : Colors.white,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f['name'],
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
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

  Widget _row(
    String label,
    String value,
    bool isDark, {
    bool bold = false,
    bool small = false,
  }) {
    return CupertinoListTile(
      backgroundColor: isDark ? kCardColorDark : Colors.white,
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      trailing: SizedBox(
        width: 200,
        child: Text(
          value,
          textAlign: TextAlign.right,
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