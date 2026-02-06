import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/constants.dart'; // 确保这里引入了 themeNotifier
import '../../services/api_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 延时加载，避免转场动画卡顿
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fetchLogs();
    });
  }

  Future<void> _fetchLogs() async {
    try {
      final l = await ApiService.getServerLogs();
      if (mounted) {
        setState(() {
          // 倒序排列，让最新的日志在最上面
          _logs = l.reversed.toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      debugPrint("获取日志失败: $e");
    }
  }

  /// 获取日志文字颜色
  /// [type] 日志级别: 8=Error, 4=Warning, 2=Info
  /// [isDark] 当前是否深色模式
  Color _getLogColor(int type, bool isDark) {
    if (type == 8) return const Color(0xFFFF3B30); // Error (Red)
    if (type == 4) return const Color(0xFFFF9500); // Warning (Orange)
    if (type == 2) return const Color(0xFF34C759); // Info (Green)
    // 普通文本：深色模式白色，浅色模式黑色
    return isDark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    // 使用 ValueListenableBuilder 监听主题变化
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          // 动态背景色
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "运行日志",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            // 动态导航栏背景
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _fetchLogs();
              },
              child: const Icon(CupertinoIcons.refresh),
            ),
          ),
          child: SafeArea(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          "暂无日志",
                          style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final msg = log['message'] ?? '';
                          final timestamp = log['timestamp'] ?? 0;
                          final type = log['type'] ?? 0;

                          // --- 🛠️ 核心修复：优先从日志文本中提取时间 ---
                          DateTime displayTime;
                          
                          // 正则说明：
                          // (\d{4}-\d{2}-\d{2}) 匹配日期 YYYY-MM-DD
                          // [T\s] 匹配中间的分隔符（T 或 空格）-> 兼容 v4 和 v5
                          // (\d{2}:\d{2}:\d{2}) 匹配时间 HH:mm:ss
                          final RegExp dateRegex = RegExp(r'(\d{4}-\d{2}-\d{2})[T\s](\d{2}:\d{2}:\d{2})');
                          final match = dateRegex.firstMatch(msg);

                          if (match != null) {
                            try {
                              // 方案 A: 提取成功，格式化为标准 ISO 格式 (替换空格为T) 解析
                              String dateStr = match.group(0)!.replaceAll(' ', 'T');
                              displayTime = DateTime.parse(dateStr);
                            } catch (e) {
                              // 解析失败兜底
                              displayTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().add(const Duration(hours: 8));
                            }
                          } else {
                            // 方案 B: 提取失败，使用 API 返回的时间戳 (手动 +8小时修正)
                            displayTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().add(const Duration(hours: 8));
                          }
                          // --- 修复结束 ---

                          // 格式化显示字符串: MM-DD HH:mm:ss
                          final timeStr = "${displayTime.month.toString().padLeft(2, '0')}-${displayTime.day.toString().padLeft(2, '0')} ${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}:${displayTime.second.toString().padLeft(2, '0')}";

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 时间戳
                                Text(
                                  "[$timeStr]",
                                  style: const TextStyle(
                                    fontFamily: 'Courier', // 等宽字体对齐好看
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 日志内容
                                Expanded(
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                      fontSize: 12,
                                      // 根据日志类型和深色模式返回颜色
                                      color: _getLogColor(type, isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
