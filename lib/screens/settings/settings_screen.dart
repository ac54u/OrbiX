import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // 🌟 用于震动反馈
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/server_manager.dart';
import '../../services/api_service.dart';

import '../server/server_list_screen.dart';
import 'log_viewer_screen.dart';
import 'feedback_screen.dart';
import 'support_screen.dart';
import 'user_agreement_screen.dart';
import 'privacy_policy_screen.dart';

// 🌟 引入隐藏页面彩蛋
import '../explore/jav_explore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _currentServer;
  String _qbtVersion = "v?.?.?";
  String _loginTime = "未知";
  int _refreshInterval = 3;
  bool _cellularWarn = true;

  bool _isOnline = false;
  int _pingMs = 0;
  Timer? _timer;

  // 🌟 彩蛋相关的变量
  int _easterEggCount = 0;
  Timer? _easterEggTimer;

  // 🚀 所有搜刮器和媒体库的控制器
  final _prowlarrUrlCtrl = TextEditingController();
  final _prowlarrKeyCtrl = TextEditingController();
  final _radarrUrlCtrl = TextEditingController();
  final _radarrKeyCtrl = TextEditingController();
  final _sonarrUrlCtrl = TextEditingController();
  final _sonarrKeyCtrl = TextEditingController();
  final _embyUrlCtrl = TextEditingController();
  final _embyKeyCtrl = TextEditingController();
  final _tmdbKeyCtrl = TextEditingController();

  // 🌟 新增：私有微服务 API 控制器
  final _customApiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkServerStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkServerStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _easterEggTimer?.cancel(); // 销毁定时器
    _prowlarrUrlCtrl.dispose();
    _prowlarrKeyCtrl.dispose();
    _radarrUrlCtrl.dispose();
    _radarrKeyCtrl.dispose();
    _sonarrUrlCtrl.dispose();
    _sonarrKeyCtrl.dispose();
    _embyUrlCtrl.dispose();
    _embyKeyCtrl.dispose();
    _tmdbKeyCtrl.dispose();

    // 🌟 销毁新增的控制器
    _customApiCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    if (_currentServer == null) return;
    final stopwatch = Stopwatch()..start();
    final v = await ApiService.getAppVersion();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        if (v != null) {
          _isOnline = true;
          _pingMs = stopwatch.elapsedMilliseconds;
          _qbtVersion = v;
        } else {
          _isOnline = false;
        }
      });
    }
  }

  void _loadData() async {
    final s = await ServerManager.getCurrentServer();
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('login_time');

    setState(() {
      _currentServer = s;
      if (t != null) {
        final dt = DateTime.parse(t);
        _loginTime = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
      _refreshInterval = prefs.getInt('refresh_rate') ?? 3;
      _cellularWarn = prefs.getBool('cellular_warn') ?? true;

      // 读取本地存储的各项配置
      String defaultUrl = s != null ? "http://${s['host']}:9696" : "";
      _prowlarrUrlCtrl.text = prefs.getString('prowlarr_url') ?? defaultUrl;
      _prowlarrKeyCtrl.text = prefs.getString('prowlarr_key') ?? '';

      _radarrUrlCtrl.text = prefs.getString('radarr_url') ?? '';
      _radarrKeyCtrl.text = prefs.getString('radarr_key') ?? '';

      _sonarrUrlCtrl.text = prefs.getString('sonarr_url') ?? '';
      _sonarrKeyCtrl.text = prefs.getString('sonarr_key') ?? '';

      _embyUrlCtrl.text = prefs.getString('emby_url') ?? '';
      _embyKeyCtrl.text = prefs.getString('emby_api_key') ?? '';

      _tmdbKeyCtrl.text = prefs.getString('tmdb_key') ?? '';

      // 🌟 读取私有微服务 API 地址
      _customApiCtrl.text = prefs.getString('custom_api_url') ?? '';
    });
  }

  // 保存所有手动配置的参数
  void _saveExt() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('prowlarr_url', _prowlarrUrlCtrl.text.trim());
    await p.setString('prowlarr_key', _prowlarrKeyCtrl.text.trim());
    await p.setString('radarr_url', _radarrUrlCtrl.text.trim());
    await p.setString('radarr_key', _radarrKeyCtrl.text.trim());
    await p.setString('sonarr_url', _sonarrUrlCtrl.text.trim());
    await p.setString('sonarr_key', _sonarrKeyCtrl.text.trim());
    await p.setString('emby_url', _embyUrlCtrl.text.trim());
    await p.setString('emby_api_key', _embyKeyCtrl.text.trim());
    await p.setString('tmdb_key', _tmdbKeyCtrl.text.trim());

    // 🌟 移除首尾空格并保存私有微服务地址
    await p.setString('custom_api_url', _customApiCtrl.text.trim());

    Utils.showToast("云端扩展配置已保存");
    Navigator.pop(context);
  }

  void _saveRefreshRate(double val) async {
    final p = await SharedPreferences.getInstance();
    int r = val.toInt();
    setState(() => _refreshInterval = r);
    await p.setInt('refresh_rate', r);
  }

  void _toggleCellular(bool v) async {
    final p = await SharedPreferences.getInstance();
    setState(() => _cellularWarn = v);
    await p.setBool('cellular_warn', v);
    if (v) Utils.showToast("流量警告已开启");
  }

  // 唤出手配面板
  void _showExtSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: themeNotifier,
        builder: (context, isDark, child) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: 700,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? kCardColorDark : kBgColorLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "配置云端搜刮扩展",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 20),

                    // 🌟 新增：私有后端 API (FastAPI) 放置在最顶部
                    Text("私有后端 API (FastAPI)", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _customApiCtrl, placeholder: "http://你的VPS_IP:8000", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    // Prowlarr
                    Text("Prowlarr 地址", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _prowlarrUrlCtrl, placeholder: "http://192.168.1.x:9696", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    Text("Prowlarr API Key", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _prowlarrKeyCtrl, placeholder: "在 设置 -> 通用 中获取", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    // Radarr
                    Text("Radarr 地址", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _radarrUrlCtrl, placeholder: "http://192.168.1.x:7878", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    Text("Radarr API Key", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _radarrKeyCtrl, placeholder: "Radarr 设置获取", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    // Sonarr
                    Text("Sonarr 地址", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _sonarrUrlCtrl, placeholder: "http://192.168.1.x:8989", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    Text("Sonarr API Key", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _sonarrKeyCtrl, placeholder: "Sonarr 设置获取", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    // Emby
                    Text("Emby 地址", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _embyUrlCtrl, placeholder: "http://192.168.1.x:8096", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    Text("Emby API Key", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _embyKeyCtrl, placeholder: "在 Emby 设置 -> API 密钥获取", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    // TMDB
                    Text("TMDB API Key (选填)", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                    CupertinoTextField(controller: _tmdbKeyCtrl, placeholder: "留空则使用公共 Key", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: _saveExt,
                        child: const Text("保存并应用"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text("设置", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            border: null,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    if (_currentServer != null)
                      GestureDetector(
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ServerListScreen())),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? kCardColorDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDark ? [] : kMinimalShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("当前服务器", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 13)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _currentServer!['host'],
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (_isOnline ? CupertinoColors.activeGreen : CupertinoColors.destructiveRed).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: BoxDecoration(color: _isOnline ? CupertinoColors.activeGreen : CupertinoColors.destructiveRed, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isOnline ? "${_pingMs}ms" : "离线",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isOnline ? CupertinoColors.activeGreen : CupertinoColors.destructiveRed),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.square_stack_3d_up, size: 16, color: kPrimaryColor),
                                  const SizedBox(width: 6),
                                  Text("${_currentServer!['host']}:${_currentServer!['port']}", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.info_circle, size: 16, color: kPrimaryColor),
                                  const SizedBox(width: 6),
                                  // 🌟 将版本号包裹在 GestureDetector 中，实现隐藏彩蛋
                                  GestureDetector(
                                    onTap: () {
                                      _easterEggCount++;
                                      _easterEggTimer?.cancel();
                                      _easterEggTimer = Timer(const Duration(seconds: 2), () {
                                        _easterEggCount = 0; // 2秒内没连点完毕则重置
                                      });

                                      if (_easterEggCount >= 5) {
                                        _easterEggCount = 0;
                                        HapticFeedback.heavyImpact(); // 强震动反馈解锁
                                        Utils.showToast("🔓 已解锁深网探索模式");
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(builder: (_) => const JavExploreScreen())
                                        );
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque, // 扩大可点击区域
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 20, top: 4, bottom: 4), // 增加一些 padding 让手指更容易点中
                                      child: Text("qBittorrent $_qbtVersion", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    const Padding(
                      padding: EdgeInsets.only(left: 32, bottom: 8, top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("通用设置", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: Colors.transparent,
                      children: [
                        CupertinoListTile(
                          title: Text("列表刷新频率", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: CupertinoSlider(
                            value: _refreshInterval.toDouble(),
                            min: 1, max: 10, divisions: 9,
                            onChanged: (v) => _saveRefreshRate(v),
                          ),
                          trailing: Text("${_refreshInterval}s", style: const TextStyle(color: Colors.grey)),
                        ),
                        CupertinoListTile(
                          title: Text("云端搜刮扩展", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("配置 Prowlarr, Radarr, Sonarr 等", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.cloud_bolt_fill, color: CupertinoColors.activeBlue),
                          trailing: const CupertinoListTileChevron(),
                          onTap: _showExtSettings,
                        ),
                        CupertinoListTile(
                          title: Text("运行日志", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          leading: const Icon(CupertinoIcons.news, color: Colors.blueGrey),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const LogViewerScreen())),
                        ),
                        CupertinoListTile(
                          title: Text("流量预警", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("使用流量时弹出提示", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Colors.green),
                          trailing: CupertinoSwitch(value: _cellularWarn, onChanged: _toggleCellular),
                        ),
                        CupertinoListTile(
                          title: Text("意见反馈", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("提交建议或Bug", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.chat_bubble_text_fill, color: kPrimaryColor),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => Navigator.push(context, CupertinoPageRoute(fullscreenDialog: true, builder: (context) => const FeedbackScreen())),
                        ),
                        CupertinoListTile(
                          title: Text("隐私政策", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("我们如何处理数据", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.lock_shield_fill, color: Colors.blue),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                        ),
                        CupertinoListTile(
                          title: Text("用户协议", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("免责声明与使用规范", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.doc_text_fill, color: Colors.orange),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const UserAgreementScreen())),
                        ),
                         CupertinoListTile(
                          title: Text("支持作者", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("请我喝杯咖啡", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.heart_fill, color: Colors.red),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const SupportScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}