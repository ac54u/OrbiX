import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/arr_api_service.dart';
import '../../core/constants.dart'; // 如果你有定义颜色的文件
// 注意：如果你没有 kBgColorDark 等常量，可以直接用 Theme.of(context) 替代

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

  // 辅助方法：根据状态返回对应的颜色
  Color _getStatusColor(String status) {
    if (status == '已下载') return CupertinoColors.activeGreen;
    if (status == '等待中' || status == '待首播') return CupertinoColors.activeOrange;
    return CupertinoColors.systemGrey;
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
        title: Text(
          '媒体日历',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              CupertinoIcons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _loadCalendar,
          ),
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
                      Text("未来 7 天没有新媒体或未配置接口", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
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
                      // 格式化日期：如 "3月25日 20:00"
                      final dateStr = DateFormat('M月d日 HH:mm').format(item.date);
                      final isMovie = item.type == 'Movie';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // 未来可以扩展：点击跳转到该电影的详情页
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 左侧海报
                                  Hero(
                                    tag: 'poster_${item.title}_$index',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: item.posterUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: item.posterUrl,
                                              width: 60,
                                              height: 90,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 60,
                                                height: 90,
                                                color: isDark ? Colors.white10 : Colors.black12,
                                                child: const CupertinoActivityIndicator(),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: 60,
                                                height: 90,
                                                color: isDark ? Colors.white10 : Colors.black12,
                                                child: Icon(isMovie ? CupertinoIcons.film : CupertinoIcons.tv, color: Colors.grey),
                                              ),
                                            )
                                          : Container(
                                              width: 60,
                                              height: 90,
                                              color: isDark ? Colors.white10 : Colors.black12,
                                              child: Icon(isMovie ? CupertinoIcons.film : CupertinoIcons.tv, color: Colors.grey),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // 中间信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isMovie 
                                                    ? CupertinoColors.activeBlue.withOpacity(0.15) 
                                                    : CupertinoColors.systemPurple.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isMovie ? '电影' : '剧集',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isMovie ? CupertinoColors.activeBlue : CupertinoColors.systemPurple,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(CupertinoIcons.clock, size: 12, color: isDark ? Colors.white54 : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateStr,
                                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // 右侧状态
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        item.status == '已下载' ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.time,
                                        color: _getStatusColor(item.status),
                                        size: 24,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: _getStatusColor(item.status),
                                        ),
                                      ),
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