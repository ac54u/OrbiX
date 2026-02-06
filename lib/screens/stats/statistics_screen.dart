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
  String _appVersion = "Unknown";
  final List<FlSpot> _dlSpots = [];
  final List<FlSpot> _upSpots = [];
  double _timeCounter = 0;
  final int _maxPoints = 30;
  Timer? _timer;

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
    if (_appVersion == "Unknown") {
      final v = await ApiService.getAppVersion();
      if (v != null) setState(() => _appVersion = v);
    }

    if (data != null && mounted) {
      setState(() {
        _serverData = data;
        final serverState = data['server_state'] ?? {};
        final double dlSpeed = (serverState['dl_info_speed'] ?? 0) / 1024.0;
        final double upSpeed = (serverState['up_info_speed'] ?? 0) / 1024.0;

        _timeCounter++;
        _dlSpots.removeAt(0);
        _dlSpots.add(FlSpot(_timeCounter, dlSpeed));
        _upSpots.removeAt(0);
        _upSpots.add(FlSpot(_timeCounter, upSpeed));
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

  List<Map<String, dynamic>> _calculateMilestones(Map<String, dynamic> data) {
    final serverState = data['server_state'] ?? {};
    final totalDl = serverState['alltime_dl'] ?? 0; 
    final totalUp = serverState['alltime_ul'] ?? 0; 
    
    final dlGb = totalDl / 1024 / 1024 / 1024;
    
    return [
      {
        'icon': CupertinoIcons.tray_arrow_down,
        'color': Colors.blue,
        'title': '下载新手',
        'desc': '累计下载 10GB',
        'achieved': dlGb >= 10,
      },
      {
        'icon': CupertinoIcons.layers_alt_fill,
        'color': Colors.purple,
        'title': '数据收藏家',
        'desc': '累计下载 1TB',
        'achieved': dlGb >= 1024,
      },
      {
        'icon': CupertinoIcons.share_solid,
        'color': Colors.green,
        'title': '无私奉献',
        'desc': '累计上传 > 100GB',
        'achieved': (totalUp / 1024 / 1024 / 1024) >= 100,
      },
      {
        'icon': CupertinoIcons.bolt_horizontal_fill,
        'color': Colors.orange,
        'title': '极速狂飙',
        'desc': '速度破 50MB/s',
        'achieved': (serverState['dl_info_speed'] ?? 0) > 50 * 1024 * 1024,
      },
    ];
  }

  // 修改点：传入 isDark 参数
  Widget _buildMilestoneList(bool isDark) {
    final milestones = _calculateMilestones(_serverData);

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final m = milestones[index];
          final bool achieved = m['achieved'];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: achieved 
                  ? (m['color'] as Color).withOpacity(0.1) 
                  : (isDark ? Colors.white10 : Colors.grey[200]),
              borderRadius: BorderRadius.circular(16),
              border: achieved ? Border.all(color: (m['color'] as Color).withOpacity(0.5)) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  m['icon'], 
                  color: achieved ? m['color'] : Colors.grey, 
                  size: 28
                ),
                const Spacer(),
                Text(
                  m['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: achieved ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['desc'],
                  style: TextStyle(fontSize: 10, color: achieved ? Colors.grey : Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverState = _serverData['server_state'] ?? {};
    final dlSession = Utils.formatBytes(serverState['dl_info_data'] ?? 0);
    final upSession = Utils.formatBytes(serverState['up_info_data'] ?? 0);
    final dlSpeedStr = "${Utils.formatBytes(serverState['dl_info_speed'] ?? 0)}/s";
    final upSpeedStr = "${Utils.formatBytes(serverState['up_info_speed'] ?? 0)}/s";
    final freeSpace = Utils.formatBytes(serverState['free_space_on_disk'] ?? 0);
    final totalDl = Utils.formatBytes(serverState['alltime_dl'] ?? 0);
    final totalUp = Utils.formatBytes(serverState['alltime_ul'] ?? 0);
    final ratioRaw = serverState['global_ratio'];
    final ratio = (ratioRaw is num)
        ? ratioRaw.toStringAsFixed(2)
        : (ratioRaw ?? "0.00");

    // 修改点：使用 ValueListenableBuilder 包裹 Scaffold
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
                      child: Text(
                        "成就里程碑", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 20,
                          color: isDark ? Colors.white : Colors.black,
                        )
                      ),
                    ),
                    _buildMilestoneList(isDark), // 传入 isDark
                    const SizedBox(height: 20),

                    _buildInfoCard(
                      isDark: isDark,
                      title: "服务器",
                      rows: [
                        _buildInfoRow("qBittorrent 版本", _appVersion, isDark, bold: true),
                      ],
                    ),
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
                        "当前会话",
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
                      color: const Color(0xFF34C759),
                      spots: _upSpots,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      isDark: isDark,
                      title: "硬盘",
                      rows: [_buildInfoRow("剩余空间", freeSpace, isDark, bold: true)],
                    ),
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
              Text(
                speedValue,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
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
                    belowBarData: BarAreaData(show: false),
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