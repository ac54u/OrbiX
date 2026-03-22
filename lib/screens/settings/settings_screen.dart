import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
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
  final _configUrlCtrl = TextEditingController(); // 云端配置链接

  // 扩展服务的所有输入框
  final _prowlarrUrlCtrl = TextEditingController();
  final _prowlarrKeyCtrl = TextEditingController();
  final _radarrUrlCtrl = TextEditingController();
  final _radarrKeyCtrl = TextEditingController();
  final _sonarrUrlCtrl = TextEditingController();
  final _sonarrKeyCtrl = TextEditingController();
  final _embyUrlCtrl = TextEditingController();
  final _embyKeyCtrl = TextEditingController();
  final _tmdbKeyCtrl = TextEditingController();

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
    _configUrlCtrl.dispose();
    _prowlarrUrlCtrl.dispose();
    _prowlarrKeyCtrl.dispose();
    _radarrUrlCtrl.dispose();
    _radarrKeyCtrl.dispose();
    _sonarrUrlCtrl.dispose();
    _sonarrKeyCtrl.dispose();
    _embyUrlCtrl.dispose();
    _embyKeyCtrl.dispose();
    _tmdbKeyCtrl.dispose();
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

      _configUrlCtrl.text = prefs.getString('cloud_config_url') ?? "";
      _prowlarrUrlCtrl.text = prefs.getString('prowlarr_url') ?? (s != null ? "http://${s['host']}:9696" : "");
      _prowlarrKeyCtrl.text = prefs.getString('prowlarr_key') ?? '';
      _radarrUrlCtrl.text = prefs.getString('radarr_url') ?? '';
      _radarrKeyCtrl.text = prefs.getString('radarr_key') ?? '';
      _sonarrUrlCtrl.text = prefs.getString('sonarr_url') ?? '';
      _sonarrKeyCtrl.text = prefs.getString('sonarr_key') ?? '';
      _embyUrlCtrl.text = prefs.getString('emby_url') ?? '';
      _embyKeyCtrl.text = prefs.getString('emby_key') ?? '';
      _tmdbKeyCtrl.text = prefs.getString('tmdb_key') ?? '';
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

  void _saveExt() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cloud_config_url', _configUrlCtrl.text);
    await p.setString('prowlarr_url', _prowlarrUrlCtrl.text);
    await p.setString('prowlarr_key', _prowlarrKeyCtrl.text);
    await p.setString('radarr_url', _radarrUrlCtrl.text);
    await p.setString('radarr_key', _radarrKeyCtrl.text);
    await p.setString('sonarr_url', _sonarrUrlCtrl.text);
    await p.setString('sonarr_key', _sonarrKeyCtrl.text);
    await p.setString('emby_url', _embyUrlCtrl.text);
    await p.setString('emby_key', _embyKeyCtrl.text);
    await p.setString('tmdb_key', _tmdbKeyCtrl.text);
    Utils.showToast("扩展配置已保存");
    Navigator.pop(context);
  }

  // --- 核心：一键拉取云端 JSON 配置 ---
  Future<void> _fetchCloudConfig() async {
    FocusScope.of(context).unfocus();
    if (_configUrlCtrl.text.isEmpty) {
      Utils.showToast("请输入云端配置文件链接");
      return;
    }
    try {
      Utils.showToast("正在拉取云端配置...");
      final response = await Dio().get(_configUrlCtrl.text);
      
      Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data);
      } else {
        data = response.data;
      }

      setState(() {
        if (data['prowlarr_url'] != null) _prowlarrUrlCtrl.text = data['prowlarr_url'];
        if (data['prowlarr_key'] != null) _prowlarrKeyCtrl.text = data['prowlarr_key'];
        if (data['radarr_url'] != null) _radarrUrlCtrl.text = data['radarr_url'];
        if (data['radarr_key'] != null) _radarrKeyCtrl.text = data['radarr_key'];
        if (data['sonarr_url'] != null) _sonarrUrlCtrl.text = data['sonarr_url'];
        if (data['sonarr_key'] != null) _sonarrKeyCtrl.text = data['sonarr_key'];
        if (data['emby_url'] != null) _embyUrlCtrl.text = data['emby_url'];
        if (data['emby_key'] != null) _embyKeyCtrl.text = data['emby_key'];
        if (data['tmdb_key'] != null) _tmdbKeyCtrl.text = data['tmdb_key'];
      });
      Utils.showToast("✅ 配置解析成功，请点击底部保存");
    } catch (e) {
      Utils.showToast("❌ 拉取失败，请检查链接或文件格式");
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

  // 扩展输入框构建提取复用，保持代码清爽
  Widget _buildExtInputBox(String title, TextEditingController ctrl, bool isDark, {String placeholder = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        CupertinoTextField(
          controller: ctrl,
          placeholder: placeholder,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showExtSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ValueListenableBuilder<bool>(
        valueListenable: themeNotifier,
        builder: (context, isDark, child) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85, // 弹窗加高以容纳更多字段
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? kCardColorDark : kBgColorLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "扩展服务配置",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("完成", style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 一键拉取云端配置区域 ---
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.blueGrey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(CupertinoIcons.cloud_download_fill, color: CupertinoColors.activeBlue, size: 18),
                                    const SizedBox(width: 6),
                                    Text("云端一键导入", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: _configUrlCtrl,
                                        placeholder: "https://你的域名/config.json",
                                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                                        padding: const EdgeInsets.all(10),
                                        clearButtonMode: OverlayVisibilityMode.editing,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      color: CupertinoColors.activeBlue,
                                      minSize: 36,
                                      onPressed: _fetchCloudConfig,
                                      child: const Text("拉取", style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          _buildExtInputBox("Prowlarr 地址", _prowlarrUrlCtrl, isDark),
                          _buildExtInputBox("Prowlarr API Key", _prowlarrKeyCtrl, isDark),
                          
                          _buildExtInputBox("Radarr 地址", _radarrUrlCtrl, isDark),
                          _buildExtInputBox("Radarr API Key", _radarrKeyCtrl, isDark),

                          _buildExtInputBox("Sonarr 地址", _sonarrUrlCtrl, isDark),
                          _buildExtInputBox("Sonarr API Key", _sonarrKeyCtrl, isDark),

                          _buildExtInputBox("Emby 地址", _embyUrlCtrl, isDark),
                          _buildExtInputBox("Emby API Key", _embyKeyCtrl, isDark),

                          _buildExtInputBox("TMDB API Key (选填)", _tmdbKeyCtrl, isDark, placeholder: "留空则使用公共 Key"),
                          
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: _saveExt,
                              child: const Text("保存全部设置"),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
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
                        CupertinoListTile(
                          title: Text("搜刮器配置", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text("配置 Prowlarr & TMDB 等扩展", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                          leading: const Icon(CupertinoIcons.search_circle_fill, color: Colors.purple),
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
