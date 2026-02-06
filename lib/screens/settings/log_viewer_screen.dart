import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/constants.dart';
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
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fetchLogs();
    });
  }

  Future<void> _fetchLogs() async {
    try {
      final l = await ApiService.getServerLogs();
      if (mounted) {
        setState(() {
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

  Color _getLogColor(int type, bool isDark) {
    if (type == 8) return const Color(0xFFFF3B30); // Error
    if (type == 4) return const Color(0xFFFF9500); // Warning
    if (type == 2) return const Color(0xFF34C759); // Info
    return isDark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "运行日志",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
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
                          int timestamp = log['timestamp'] ?? 0;
                          final type = log['type'] ?? 0;

                          // 🛠️ 核心修复：自动判断“秒”还是“毫秒”
                          // 如果数字小于 100亿 (10位数)，说明是秒，需要乘以 1000 转毫秒
                          if (timestamp < 10000000000) {
                            timestamp = timestamp * 1000;
                          }

                          // 转换时间 + 8小时时区修正
                          DateTime displayTime = DateTime.fromMillisecondsSinceEpoch(timestamp)
                              .toUtc()
                              .add(const Duration(hours: 8));

                          final timeStr = "${displayTime.month.toString().padLeft(2, '0')}-${displayTime.day.toString().padLeft(2, '0')} ${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}:${displayTime.second.toString().padLeft(2, '0')}";

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "[$timeStr]",
                                  style: const TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                      fontSize: 12,
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
