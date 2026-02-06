import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/server_manager.dart';
import '../../services/api_service.dart';
import '../main_tab_scaffold.dart';

class ServerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? editServer;
  final int? editIndex;
  const ServerFormScreen({super.key, this.editServer, this.editIndex});

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: "8080");
  final _userCtrl = TextEditingController(text: "admin");
  final _passCtrl = TextEditingController();
  bool _useHttps = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    if (widget.editServer != null) {
      _nameCtrl.text = widget.editServer!['name'];
      _hostCtrl.text = widget.editServer!['host'];
      _portCtrl.text = widget.editServer!['port'];
      _userCtrl.text = widget.editServer!['user'];
      _passCtrl.text = widget.editServer!['pass'];
      _useHttps = widget.editServer!['https'] ?? false;
    }
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    setState(() => _testing = true);

    final config = {
      'host': _hostCtrl.text,
      'port': _portCtrl.text,
      'user': _userCtrl.text,
      'pass': _passCtrl.text,
      'https': _useHttps,
    };

    bool ok = await ApiService.testConnection(config);
    setState(() => _testing = false);
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Icon(
          ok
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.xmark_circle_fill,
          color: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
          size: 40,
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            ok ? "连接成功！" : "连接失败，请检查配置。",
            style: TextStyle(
              fontSize: 16,
              color: themeNotifier.value ? Colors.white : Colors.black,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("好"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_hostCtrl.text.isEmpty) {
      Utils.showToast("请输入主机地址");
      return;
    }

    final server = {
      'name': _nameCtrl.text.isEmpty ? _hostCtrl.text : _nameCtrl.text,
      'host': _hostCtrl.text,
      'port': _portCtrl.text,
      'user': _userCtrl.text,
      'pass': _passCtrl.text,
      'https': _useHttps,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (widget.editIndex != null) {
      await ServerManager.updateServer(widget.editIndex!, server);
    } else {
      await ServerManager.addServer(server);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      CupertinoPageRoute(builder: (_) => const MainTabScaffold()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 使用 ValueListenableBuilder 监听主题
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              widget.editServer != null ? "编辑服务器" : "添加服务器",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _save,
              child: const Text(
                "保存",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: ListView(
            children: [
              const SizedBox(height: 20),
              CupertinoListSection.insetGrouped(
                backgroundColor: isDark ? kBgColorDark : kBgColorLight,
                decoration: BoxDecoration(
                  color: isDark ? kCardColorDark : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                header: const Text("服务器信息"),
                children: [
                  _input("名称", _nameCtrl, "例如: Nas", isDark),
                  _input("主机", _hostCtrl, "IP 或 域名", isDark),
                  _input("端口", _portCtrl, "8080", isDark),
                ],
              ),
              CupertinoListSection.insetGrouped(
                backgroundColor: isDark ? kBgColorDark : kBgColorLight,
                decoration: BoxDecoration(
                  color: isDark ? kCardColorDark : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                header: const Text("认证"),
                children: [
                  _input("用户名", _userCtrl, "admin", isDark),
                  _input("密码", _passCtrl, "必填", isDark, obscure: true),
                  CupertinoListTile(
                    backgroundColor: isDark ? kCardColorDark : Colors.white,
                    title: Text(
                      "使用 HTTPS",
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    trailing: CupertinoSwitch(
                      value: _useHttps,
                      onChanged: (v) => setState(() => _useHttps = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton(
                  color: isDark ? kCardColorDark : Colors.white,
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const CupertinoActivityIndicator()
                      : Text(
                          "测试连接",
                          style: TextStyle(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _input(
    String label,
    TextEditingController c,
    String p,
    bool isDark, {
    bool obscure = false,
  }) {
    return CupertinoListTile(
      backgroundColor: isDark ? kCardColorDark : Colors.white,
      title: SizedBox(
        width: 70, 
        child: Text(
          label,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
      ),
      trailing: SizedBox(
        width: 180,
        child: CupertinoTextField(
          controller: c,
          placeholder: p,
          obscureText: obscure,
          textAlign: TextAlign.right,
          decoration: null,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          placeholderStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}