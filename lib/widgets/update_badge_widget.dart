import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class UpdateBadgeWidget extends StatefulWidget {
  final Widget child; // 👈 1. 增加接收传入 Widget 的属性

  const UpdateBadgeWidget({
    super.key, 
    required this.child, // 👈 2. 构造函数中声明必传 child
  });

  @override
  State<UpdateBadgeWidget> createState() => _UpdateBadgeWidgetState();
}

class _UpdateBadgeWidgetState extends State<UpdateBadgeWidget> {
  bool _hasUpdate = false;
  Map<String, dynamic>? _updateInfo;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    
    final info = await ApiService.checkAppUpdate(_currentVersion);
    if (info != null && info['hasUpdate'] == true && mounted) {
      setState(() {
        _hasUpdate = true;
        _updateInfo = info;
      });
    }
  }

  void _showUpdateDialog() {
    if (_updateInfo == null) return;
    
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text("发现新版本 v${_updateInfo!['version']}"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(_updateInfo!['notes'], textAlign: TextAlign.left),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("立即更新"),
            onPressed: () async {
              Navigator.pop(ctx);
              
              String ipaUrl = _updateInfo!['ipaUrl'];
              String htmlUrl = _updateInfo!['url'];
              
              // 🚀 核心：通过 URL Scheme 直接唤醒 TrollStore 下载并覆盖安装
              if (ipaUrl.isNotEmpty) {
                // apple-magnifier 是巨魔伪装放大镜的专属 URL Scheme
                final trollStoreUrl = Uri.parse('apple-magnifier://install?url=$ipaUrl');
                if (await canLaunchUrl(trollStoreUrl)) {
                  await launchUrl(trollStoreUrl, mode: LaunchMode.externalApplication);
                  return;
                }
              }
              
              // 备用方案：如果没有巨魔环境或未上传 ipa，则跳转浏览器打开 GitHub 发布页
              final webUrl = Uri.parse(htmlUrl);
              if (await canLaunchUrl(webUrl)) {
                await launchUrl(webUrl, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hasUpdate ? _showUpdateDialog : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child, // 👈 3. 原封不动地渲染外部传进来的 Icon
          if (_hasUpdate)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1C1C1E), width: 2), // 适配暗黑模式底色
                ),
              ),
            ),
        ],
      ),
    );
  }
}