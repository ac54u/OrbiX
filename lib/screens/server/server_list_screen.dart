import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/server_manager.dart';
import '../../services/api_service.dart';
import 'server_form_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  List<Map<String, dynamic>> _servers = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  void _loadServers() async {
    final list = await ServerManager.getServers();
    final idx = await ServerManager.getCurrentIndex();
    setState(() {
      _servers = list;
      _currentIndex = idx;
    });
  }

  void _selectServer(int index) async {
    await ServerManager.setCurrentIndex(index);
    setState(() => _currentIndex = index);
    HapticFeedback.mediumImpact();
    Utils.showToast("已切换到 ${_servers[index]['name']}");

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookie');
    bool loginSuccess = await ApiService.login();

    if (loginSuccess) {
      await prefs.setString('login_time', DateTime.now().toIso8601String());
    } else {
      Utils.showToast("登录新服务器失败");
    }
  }

  void _deleteServer(int index) async {
    await ServerManager.removeServer(index);
    _loadServers();
  }

  @override
  Widget build(BuildContext context) {
    // 1. 监听主题变化
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "服务器管理",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ServerFormScreen()),
              ).then((_) => _loadServers()),
            ),
          ),
          child: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 20, bottom: 40),
              itemCount: _servers.length,
              itemBuilder: (context, index) {
                final s = _servers[index];
                final bool isActive = index == _currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Slidable(
                      key: ValueKey(index),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        extentRatio: 0.4,
                        children: [
                          SlidableAction(
                            onPressed: (ctx) {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) => ServerFormScreen(
                                    editServer: s,
                                    editIndex: index,
                                  ),
                                ),
                              ).then((_) => _loadServers());
                            },
                            backgroundColor: const Color(0xFFFF9500),
                            foregroundColor: Colors.white,
                            icon: CupertinoIcons.pencil,
                            label: '编辑',
                          ),
                          SlidableAction(
                            onPressed: (ctx) => _deleteServer(index),
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                            icon: CupertinoIcons.delete,
                            label: '删除',
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => _selectServer(index),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            // 2. 动态设置卡片颜色
                            color: isDark ? kCardColorDark : Colors.white,
                            border: isActive
                                ? Border.all(color: kPrimaryColor, width: 2)
                                : Border.all(color: Colors.transparent, width: 2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: kMinimalShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF34C759)
                                      : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        // 3. 动态设置文字颜色
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "${s['https'] == true ? 'https' : 'http'}://${s['host']}:${s['port']}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "用户: ${s['user']}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive)
                                const Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: kPrimaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
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