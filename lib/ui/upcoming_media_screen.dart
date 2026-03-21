import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/arr_api_service.dart';

class UpcomingMediaScreen extends StatefulWidget {
  const UpcomingMediaScreen({super.key});

  @override
  State<UpcomingMediaScreen> createState() => _UpcomingMediaScreenState();
}

class _UpcomingMediaScreenState extends State<UpcomingMediaScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);
    final items = await ArrApiService.getUpcomingCalendar();
    if (mounted) {
      setState(() {
        _mediaItems = items;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    if (status == '已下载') return CupertinoColors.activeGreen;
    if (status == '等待中' || status == '待首播') return CupertinoColors.activeOrange;
    return CupertinoColors.systemGrey;
  }

  // 🚀 核心新增：点击弹出资讯详情面板
  void _showMediaDetails(BuildContext context, MediaItem item, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // 占屏幕 70% 高度
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部指示条
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              // 海报与核心参数区
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.posterUrl,
                            width: 110, height: 165, fit: BoxFit.cover,
                            placeholder: (context, url) => Container(width: 110, height: 165, color: Colors.grey[800], child: const CupertinoActivityIndicator()),
                            errorWidget: (context, url, error) => Container(width: 110, height: 165, color: Colors.grey[800], child: const Icon(CupertinoIcons.film)),
                          )
                        : Container(width: 110, height: 165, color: Colors.grey[800], child: const Icon(CupertinoIcons.film)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 12),
                        _buildDetailRow(CupertinoIcons.calendar, DateFormat('yyyy年M月d日').format(item.date), isDark),
                        const SizedBox(height: 8),
                        _buildDetailRow(CupertinoIcons.time, "${item.runtime} 分钟", isDark),
                        const SizedBox(height: 8),
                        _buildDetailRow(CupertinoIcons.tv, item.network.isNotEmpty ? item.network : "未知厂牌", isDark),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 16),
              // 剧情简介区
              Text("剧情简介", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    item.overview,
                    style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('媒体日历', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
        actions: [
          IconButton(icon: Icon(CupertinoIcons.refresh, color: isDark ? Colors.white : Colors.black), onPressed: _loadCalendar),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _mediaItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.calendar_badge_minus, size: 64, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(height: 16),
                      Text("未来 7 天没有新媒体", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCalendar,
                  color: CupertinoColors.activeBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: _mediaItems.length,
                    itemBuilder: (context, index) {
                      final item = _mediaItems[index];
                      final dateStr = DateFormat('M月d日 HH:mm').format(item.date);
                      final isMovie = item.type == 'Movie';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            // 🚀 点击触发面板
                            onTap: () => _showMediaDetails(context, item, isDark),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.posterUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item.posterUrl,
                                            width: 60, height: 90, fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(width: 60, height: 90, color: isDark ? Colors.white10 : Colors.black12, child: const CupertinoActivityIndicator()),
                                            errorWidget: (context, url, error) => Container(width: 60, height: 90, color: isDark ? Colors.white10 : Colors.black12, child: Icon(isMovie ? CupertinoIcons.film : CupertinoIcons.tv, color: Colors.grey)),
                                          )
                                        : Container(width: 60, height: 90, color: isDark ? Colors.white10 : Colors.black12, child: Icon(isMovie ? CupertinoIcons.film : CupertinoIcons.tv, color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: isMovie ? CupertinoColors.activeBlue.withOpacity(0.15) : CupertinoColors.systemPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                              child: Text(isMovie ? '电影' : '剧集', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isMovie ? CupertinoColors.activeBlue : CupertinoColors.systemPurple)),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(CupertinoIcons.clock, size: 12, color: isDark ? Colors.white54 : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(dateStr, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(item.status == '已下载' ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.time, color: _getStatusColor(item.status), size: 24),
                                      const SizedBox(height: 4),
                                      Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _getStatusColor(item.status))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
