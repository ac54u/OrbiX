import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import 'speed_limit_sheet.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _serverData = {};
  final List<FlSpot> _dlSpots = [];
  final List<FlSpot> _upSpots = [];
  double _timeCounter = 0;
  final int _maxPoints = 30;
  Timer? _timer;

  double _peakDlSpeed = 0;
  double _peakUpSpeed = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _maxPoints; i++) {
      _dlSpots.add(FlSpot(i.toDouble(), 0));
      _upSpots.add(FlSpot(i.toDouble(), 0));
    }
    _timeCounter = _maxPoints.toDouble();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await ApiService.getMainData();

    if (mounted) {
      setState(() {
        if (data != null) {
          _serverData = data;
          
          final serverState = data['server_state'] ?? {};
          final double dlSpeed = (serverState['dl_info_speed'] ?? 0) / 1024.0;
          final double upSpeed = (serverState['up_info_speed'] ?? 0) / 1024.0;

          if (dlSpeed > _peakDlSpeed) _peakDlSpeed = dlSpeed;
          if (upSpeed > _peakUpSpeed) _peakUpSpeed = upSpeed;

          _timeCounter++;
          _dlSpots.removeAt(0);
          _dlSpots.add(FlSpot(_timeCounter, dlSpeed));
          _upSpots.removeAt(0);
          _upSpots.add(FlSpot(_timeCounter, upSpeed));
        }
      });
    }
  }

  void _showLimitSheet() async {
    final info = await ApiService.getTransferInfo();
    if (info == null) return;
    int dl = info['dl_info_limit'] ?? 0;
    int up = info['up_info_limit'] ?? 0;

    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => SpeedLimitSheet(initialDl: dl, initialUp: up),
    );
  }

  Map<String, int> _getTaskCounts() {
    int dl = 0, up = 0, paused = 0, error = 0;
    final torrents = _serverData['torrents'] as Map<String, dynamic>? ?? {};
    
    for (var t in torrents.values) {
      final state = t['state'] as String? ?? '';
      if (state.contains('downloading') || state.contains('DL')) {
        dl++;
      } else if (state.contains('uploading') || state.contains('UP')) {
        up++;
      } else if (state.contains('paused')) {
        paused++;
      } else if (state.contains('error') || state.contains('missing')) {
        error++;
      }
    }
    return {'dl': dl, 'up': up, 'paused': paused, 'error': error};
  }

  @override
  Widget build(BuildContext context) {
    final serverState = _serverData['server_state'] ?? {};
    final dlSession = Utils.formatBytes(serverState['dl_info_data'] ?? 0);
    final upSession = Utils.formatBytes(serverState['up_info_data'] ?? 0);
    final dlSpeedStr = "${Utils.formatBytes(serverState['dl_info_speed'] ?? 0)}/s";
    final upSpeedStr = "${Utils.formatBytes(serverState['up_info_speed'] ?? 0)}/s";
    
    final peakDlStr = "${Utils.formatBytes((_peakDlSpeed * 1024).toInt())}/s";
    final peakUpStr = "${Utils.formatBytes((_peakUpSpeed * 1024).toInt())}/s";

    final freeSpaceStr = Utils.formatBytes(serverState['free_space_on_disk'] ?? 0);
    final totalDl = Utils.formatBytes(serverState['alltime_dl'] ?? 0);
    final totalUp = Utils.formatBytes(serverState['alltime_ul'] ?? 0);
    final ratioRaw = serverState['global_ratio'];
    final ratio = (ratioRaw is num) ? ratioRaw.toStringAsFixed(2) : (ratioRaw ?? "0.00");
    
    final bool useAltSpeed = serverState['use_alt_speed_limits'] ?? false;
    final taskCounts = _getTaskCounts();

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text("统计", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showLimitSheet,
              child: const Icon(CupertinoIcons.thermometer, size: 24),
            ),
          ),
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await _fetch();
                  return Future.delayed(const Duration(milliseconds: 500));
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    _buildQuickActionBar(isDark, useAltSpeed),
                    const SizedBox(height: 16),

                    _buildTaskOverviewCards(isDark, taskCounts),
                    const SizedBox(height: 16),

                    _buildInfoCard(
                      isDark: isDark,
                      title: "历史统计",
                      rows: [
                        _buildIconRow(CupertinoIcons.tray_arrow_down_fill, kPrimaryColor, "总下载量", totalDl, isDark),
                        _buildIconRow(CupertinoIcons.tray_arrow_up_fill, const Color(0xFF34C759), "总上传量", totalUp, isDark),
                        _buildIconRow(CupertinoIcons.graph_circle_fill, const Color(0xFFFF9500), "分享率", ratio.toString(), isDark),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        "当前会话速度",
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildChartCard(
                      isDark: isDark,
                      title: "下载",
                      sessionLabel: "本次下载",
                      sessionValue: dlSession,
                      speedLabel: "下载速率",
                      speedValue: dlSpeedStr,
                      peakValue: peakDlStr,
                      color: kPrimaryColor,
                      spots: _dlSpots,
                    ),
                    const SizedBox(height: 12),
                    _buildChartCard(
                      isDark: isDark,
                      title: "上传",
                      sessionLabel: "本次上传",
                      sessionValue: upSession,
                      speedLabel: "上传速率",
                      speedValue: upSpeedStr,
                      peakValue: peakUpStr,
                      color: const Color(0xFF34C759),
                      spots: _upSpots,
                    ),
                    const SizedBox(height: 16),

                    _buildDiskSpaceCard(isDark, freeSpaceStr),
                    
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBar(bool isDark, bool useAltSpeed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? [] : kMinimalShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.tortoise_fill, 
                color: useAltSpeed ? CupertinoColors.activeOrange : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "备用限速",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: useAltSpeed,
                activeColor: CupertinoColors.activeOrange,
                onChanged: (val) async {
                  setState(() {
                    if (_serverData['server_state'] != null) {
                      _serverData['server_state']['use_alt_speed_limits'] = val;
                    }
                  });

                  try {
                    await ApiService.toggleAltSpeedLimitsMode(); 
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _fetch();
                  } catch (e) {
                    setState(() {
                      if (_serverData['server_state'] != null) {
                        _serverData['server_state']['use_alt_speed_limits'] = !val;
                      }
                    });
                    Utils.showToast("切换限速模式失败");
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: () async {
                  try {
                    await ApiService.pauseAll();
                    Utils.showToast("已暂停所有任务");
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _fetch();
                  } catch (e) {
                    Utils.showToast("暂停失败");
                  }
                },
                child: const Icon(CupertinoIcons.pause_circle_fill, color: CupertinoColors.destructiveRed, size: 28),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: () async {
                  try {
                    await ApiService.resumeAll();
                    Utils.showToast("已恢复所有任务");
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _fetch();
                  } catch (e) {
                    Utils.showToast("恢复失败");
                  }
                },
                child: const Icon(CupertinoIcons.play_circle_fill, color: CupertinoColors.activeGreen, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOverviewCards(bool isDark, Map<String, int> counts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMiniStatusCard("下载中", counts['dl'] ?? 0, kPrimaryColor, isDark),
          _buildMiniStatusCard("做种中", counts['up'] ?? 0, CupertinoColors.activeGreen, isDark),
          _buildMiniStatusCard("已暂停", counts['paused'] ?? 0, CupertinoColors.systemOrange, isDark),
          _buildMiniStatusCard("异常", counts['error'] ?? 0, CupertinoColors.destructiveRed, isDark),
        ],
      ),
    );
  }

  Widget _buildMiniStatusCard(String title, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? kCardColorDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : kMinimalShadow,
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiskSpaceCard(bool isDark, String freeSpaceStr) {
    const double diskFillRatio = 0.65; 
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? [] : kMinimalShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.device_desktop, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                "硬盘可用空间",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                freeSpaceStr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),
                FractionallySizedBox(
                  widthFactor: diskFillRatio,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryColor, Color(0xFF34C759)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconRow(IconData icon, Color iconColor, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required bool isDark,
    required String title,
    required String sessionLabel,
    required String sessionValue,
    required String speedLabel,
    required String speedValue,
    required String peakValue,
    required Color color,
    required List<FlSpot> spots,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? [] : kMinimalShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    title == "下载" ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_up_circle_fill,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    speedLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    speedValue,
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black),
                  ),
                  Text(
                    "峰值: $peakValue",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sessionLabel,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                sessionValue,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: _timeCounter - _maxPoints,
                maxX: _timeCounter,
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.35),
                          color.withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required bool isDark, required String title, required List<Widget> rows}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? kCardColorDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? [] : kMinimalShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 0, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}