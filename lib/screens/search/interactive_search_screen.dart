import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class InteractiveSearchScreen extends StatefulWidget {
  final int movieId;
  final String movieTitle;

  const InteractiveSearchScreen({super.key, required this.movieId, required this.movieTitle});

  @override
  State<InteractiveSearchScreen> createState() => _InteractiveSearchScreenState();
}

class _InteractiveSearchScreenState extends State<InteractiveSearchScreen> {
  List<dynamic> _releases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReleases();
  }

  void _fetchReleases() async {
    final results = await ApiService.getRadarrReleases(widget.movieId);
    if (mounted) {
      setState(() {
        _releases = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(widget.movieTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.slider_horizontal_3),
              onPressed: () => _showFilterPicker(isDark),
            ),
          ),
          child: _loading 
            ? const Center(child: CupertinoActivityIndicator())
            : _releases.isEmpty
              ? const Center(child: Text("未搜索到可用资源", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 100, bottom: 40),
                  itemCount: _releases.length,
                  itemBuilder: (context, index) => _buildReleaseCard(_releases[index], isDark),
                ),
        );
      },
    );
  }

  // 🌟 这里是展现“高级感”的核心卡片设计
  Widget _buildReleaseCard(dynamic r, bool isDark) {
    final bool rejected = r['rejected'] ?? false;
    final String size = Utils.formatBytes(r['size'] ?? 0);
    final String quality = r['quality']?['quality']?['name'] ?? 'Unknown';
    final int seeders = r['seeders'] ?? 0;
    final String indexer = r['indexer'] ?? 'Unknown';

    return GestureDetector(
      onTap: () => _confirmDownload(r),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? kCardColorDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : kMinimalShadow,
          border: rejected ? Border.all(color: CupertinoColors.systemRed.withOpacity(0.3), width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r['title'] ?? '',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: rejected ? Colors.grey : (isDark ? Colors.white : Colors.black),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTag(quality, CupertinoColors.activeBlue, isDark),
                const SizedBox(width: 8),
                _buildTag(size, CupertinoColors.secondaryLabel, isDark),
                const Spacer(),
                Row(
                  children: [
                    const Icon(CupertinoIcons.arrow_up_circle_fill, size: 14, color: CupertinoColors.activeGreen),
                    const SizedBox(width: 4),
                    Text("$seeders", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.activeGreen)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.cloud_download, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(indexer, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (rejected) ...[
                  const Spacer(),
                  const Icon(CupertinoIcons.info_circle, size: 14, color: CupertinoColors.systemRed),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // 点击确认下载
  void _confirmDownload(dynamic r) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("确认下载"),
        content: Text("确定要将此资源推送到下载器吗？\n\n${r['title']}"),
        actions: [
          CupertinoDialogAction(child: const Text("取消"), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              Utils.showToast("正在请求下载...");
              bool ok = await ApiService.downloadRadarrRelease(r);
              if (ok) {
                Utils.showToast("✅ 已成功发送至 qBittorrent");
                Navigator.pop(context);
              } else {
                Utils.showToast("❌ 下载请求失败");
              }
            },
            child: const Text("立即下载"),
          ),
        ],
      ),
    );
  }

  void _showFilterPicker(bool isDark) {
    // 这里可以写你想要的图4那种筛选面板逻辑
    Utils.showToast("正在开发高级筛选面板...");
  }
}
