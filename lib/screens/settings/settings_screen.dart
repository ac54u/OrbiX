import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  
  final _pathCtrl = TextEditingController(); 

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
    _pathCtrl.dispose();
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
      _pathCtrl.text = prefs.getString('default_path') ?? "/data/Movies";
      _cellularWarn = prefs.getBool('cellular_warn') ?? true;
    });
  }

  Future<void> _saveDownloadPath() async {
    FocusScope.of(context).unfocus(); 
    if (_pathCtrl.text.isEmpty) {
      Utils.showToast("路径不能为空");
      return;
    }
    bool success = await ApiService.setPreferences(savePath: _pathCtrl.text);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_path', _pathCtrl.text);
      Utils.showToast("✅ 默认路径已更新");
    } else {
      Utils.showToast("❌ 更新失败，请检查连接或权限");
    }
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
                                  Text("qBittorrent $_qbtVersion", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14)),
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
                        child: Text("下载设置", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: Colors.transparent,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("默认保存路径", style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: _pathCtrl,
                                      placeholder: "/downloads",
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                      clearButtonMode: OverlayVisibilityMode.editing,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    color: CupertinoColors.activeBlue,
                                    minSize: 32,
                                    onPressed: _saveDownloadPath,
                                    child: const Text("保存", style: TextStyle(fontSize: 14, color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text("提示: 请务必填写服务器(或Docker容器)内部的真实路径", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
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
                        // 🌟 极简状态栏：只做展示，不可点击，展现高级感
                        CupertinoListTile(
                          title: Text("云端搜刮扩展", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("网关已自动装配", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.cloud_bolt_fill, color: CupertinoColors.activeBlue),
                          trailing: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: CupertinoColors.activeGreen),
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
