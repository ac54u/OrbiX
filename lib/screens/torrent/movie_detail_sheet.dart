import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RadarrStyleMovieSheet extends StatelessWidget {
  final String title;
  final String year;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final double voteAverage;
  final String quality; // 例如 "2160p REMUX"

  const RadarrStyleMovieSheet({
    super.key,
    required this.title,
    required this.year,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.voteAverage,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    // 适配你的暗黑模式变量
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 占据屏幕 70%
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias, // 确保顶部圆角裁剪内部图片
      child: Stack(
        children: [
          // 1. 顶部背景剧照 (Backdrop) + 渐变/毛玻璃遮罩
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(backdropUrl, fit: BoxFit.cover),
                // 渐变遮罩，让剧照平滑过渡到背景色
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor.withOpacity(0.1),
                        bgColor.withOpacity(0.8),
                        bgColor,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. 核心内容区
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40), // 留出剧照空间
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 左侧：竖版海报 (带阴影和圆角)
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(posterUrl, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      // 右侧：标题与元数据
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 年份与评分
                            Row(
                              children: [
                                Text(
                                  year,
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  voteAverage.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Radarr 风格的质量标签 (Badge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.3)),
                              ),
                              child: Text(
                                quality,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.activeBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // 剧情简介
                  const Text(
                    "剧情简介",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    overview,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 右上角关闭按钮
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black.withOpacity(0.4),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}