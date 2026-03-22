import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonCard extends StatelessWidget {
  final bool isDark;
  final bool isGrid; // 区分是列表模式(如下载列表)还是网格模式(如海报墙)
  
  const SkeletonCard({
    super.key, 
    required this.isDark, 
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    // 自动适配深色/浅色模式的骨架底色和微光色
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    final cardColor = isDark ? Colors.white10 : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: isGrid ? _buildGridSkeleton(cardColor, baseColor) : _buildListSkeleton(cardColor, baseColor),
    );
  }

  // 👉 1. 列表模式的骨架 (适用于 qBittorrent 任务列表)
  Widget _buildListSkeleton(Color cardColor, Color baseColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧图标位
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 16),
          // 右侧文字排版位
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Container(width: 150, height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Container(width: 80, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 👉 2. 网格模式的骨架 (适用于 Radarr/TMDB 电影海报墙)
  Widget _buildGridSkeleton(Color cardColor, Color baseColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报位
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
          ),
          // 底部文字位
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 6),
                Container(width: 60, height: 10, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
