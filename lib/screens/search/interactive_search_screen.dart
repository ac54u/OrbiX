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
  List<dynamic> _allReleases = [];
  bool _loading = true;

  // 🌟 筛选与排序状态
  bool _hideRejected = true; // 默认隐藏被 Radarr 拒绝的垃圾资源
  String _qualityFilter = 'all'; // all, 4k, 1080p
  String _sortMode = 'seeders'; // seeders, size, age

  @override
  void initState() {
    super.initState();
    _fetchReleases();
  }

  void _fetchReleases() async {
    final results = await ApiService.getRadarrReleases(widget.movieId);
    if (mounted) {
      setState(() {
        _allReleases = results;
        _loading = false;
      });
    }
  }

  // 🌟 核心逻辑：对数据进行本地过滤和排序
  List<dynamic> get _displayReleases {
    var list = List<dynamic>.from(_allReleases);

    // 1. 过滤：隐藏拒绝项
    if (_hideRejected) {
      list.retainWhere((r) => !(r['rejected'] ?? false));
    }

    // 2. 过滤：分辨率
    if (_qualityFilter != 'all') {
      list.retainWhere((r) {
        final q = (r['quality']?['quality']?['name'] ?? '').toString().toLowerCase();
        if (_qualityFilter == '4k') return q.contains('2160p') || q.contains('4k');
        if (_qualityFilter == '1080p') return q.contains('1080p');
        return true;
      });
    }

    // 3. 排序
    list.sort((a, b) {
      if (_sortMode == 'seeders') {
        return (b['seeders'] ?? 0).compareTo(a['seeders'] ?? 0);
      } else if (_sortMode == 'size') {
        return (b['size'] ?? 0).compareTo(a['size'] ?? 0);
      } else {
        // age: 假设按 age 排，越小越新
        return (a['age'] ?? 0).compareTo(b['age'] ?? 0);
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        final displayList = _displayReleases;
        
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(widget.movieTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(CupertinoIcons.line_horizontal_3_decrease_circle),
                  if (_hideRejected || _qualityFilter != 'all' || _sortMode != 'seeders')
                    Container(
                      margin: const EdgeInsets.only(top: 10, right: 2),
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: CupertinoColors.destructiveRed, shape: BoxShape.circle),
                    )
                ],
              ),
              onPressed: () => _showFilterPicker(isDark),
            ),
          ),
          child: _loading 
            ? const Center(child: CupertinoActivityIndicator())
            : displayList.isEmpty
              ? const Center(child: Text("未找到符合条件的资源", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 100, bottom: 40),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) => _buildReleaseCard(displayList[index], isDark),
                ),
        );
      },
    );
  }

  Widget _buildReleaseCard(dynamic r, bool isDark) {
    final bool rejected = r['rejected'] ?? false;
    final String size = Utils.formatBytes(r['size'] ?? 0);
    final String quality = r['quality']?['quality']?['name'] ?? 'Unknown';
    final int seeders = r['seeders'] ?? 0;
    final String indexer = r['indexer'] ?? 'Unknown';
    
    // 如果被拒收，提取拒收原因
    List<String> rejections = [];
    if (rejected && r['rejections'] != null) {
      rejections = (r['rejections'] as List).map((e) => e.toString()).toList();
    }

    bool is4K = quality.toUpperCase().contains('4K') || quality.toUpperCase().contains('2160P');

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
                decoration: rejected ? TextDecoration.lineThrough : null, // 拒收的加个删除线
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTag(quality, is4K ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue, isDark),
                const SizedBox(width: 8),
                _buildTag(size, CupertinoColors.secondaryLabel, isDark),
                const Spacer(),
                Row(
                  children: [
                    Icon(CupertinoIcons.arrow_up_circle_fill, size: 14, color: seeders > 0 ? CupertinoColors.activeGreen : Colors.grey),
                    const SizedBox(width: 4),
                    Text("$seeders", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: seeders > 0 ? CupertinoColors.activeGreen : Colors.grey)),
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
                const Spacer(),
                if (r['indexerFlags'] != null && (r['indexerFlags'] as List).contains('freeleech'))
                   const Text("🆓 免费", style: TextStyle(fontSize: 10, color: CupertinoColors.activeOrange, fontWeight: FontWeight.bold)),
              ],
            ),
            // 展现拒收原因
            if (rejected && rejections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill, size: 14, color: CupertinoColors.systemRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rejections.join(" • "),
                        style: const TextStyle(fontSize: 10, color: CupertinoColors.systemRed),
                      ),
                    ),
                  ],
                ),
              )
            ]
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
                Navigator.pop(context); // 下载成功后自动退回上一页
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

  // 🌟 高级滑动面板
  void _showFilterPicker(bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: 420,
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            decoration: BoxDecoration(
              color: isDark ? kCardColorDark : kBgColorLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("显示设置", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 16),
                  
                  // 选项 1: 隐藏拒收
                  CupertinoListSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(12)),
                    children: [
                      CupertinoListTile(
                        title: Text("隐藏不符合条件的资源", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15)),
                        trailing: CupertinoSwitch(
                          value: _hideRejected,
                          onChanged: (v) {
                            setModalState(() => _hideRejected = v);
                            setState(() => _hideRejected = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 选项 2: 分辨率
                  Text("分辨率", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _qualityFilter,
                      children: const {
                        'all': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("全部")),
                        '4k': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("4K (2160p)")),
                        '1080p': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("1080p")),
                      },
                      onValueChanged: (v) {
                        if (v != null) {
                          setModalState(() => _qualityFilter = v);
                          setState(() => _qualityFilter = v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 选项 3: 排序方式
                  Text("排序方式", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _sortMode,
                      children: const {
                        'seeders': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("做种数")),
                        'size': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("体积大小")),
                        'age': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("发布时间")),
                      },
                      onValueChanged: (v) {
                        if (v != null) {
                          setModalState(() => _sortMode = v);
                          setState(() => _sortMode = v);
                        }
                      },
                    ),
                  ),
                  
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      child: const Text("完成"),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
