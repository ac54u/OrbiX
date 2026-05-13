import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class UpdateBadgeWidget extends StatefulWidget {
  final Widget child; // 接收传入 Widget

  const UpdateBadgeWidget({
    super.key,
    required this.child,
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

    // 提取信息
    final newVersion = _updateInfo!['version'];
    final releaseNotes = _updateInfo!['notes'];
    final ipaUrl = _updateInfo!['ipaUrl'] ?? '';
    final htmlUrl = _updateInfo!['url'] ?? '';

    // 使用 StatefulBuilder 让弹窗拥有自己的独立状态（用于刷新进度条）
    showCupertinoDialog(
      context: context,
      barrierDismissible: false, // 强制用户必须看弹窗
      builder: (ctx) {
        bool isDownloading = false;
        double progress = 0.0;
        String progressText = "0%";
        String sizeText = "准备下载...";
        bool downloadFailed = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(isDownloading ? "正在下载更新" : "发现新版本 v$newVersion"),
              content: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: isDownloading
                    ? _buildProgressUI(progress, progressText, sizeText, downloadFailed)
                    : Text(releaseNotes, textAlign: TextAlign.left),
              ),
              actions: isDownloading && !downloadFailed
                  ? [] // 下载中隐藏按钮，防止误触
                  : [
                      CupertinoDialogAction(
                        child: const Text("取消", style: TextStyle(color: Colors.grey)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        child: Text(downloadFailed ? "重试" : "立即更新"),
                        onPressed: () async {
                          // 如果没有 ipa 链接，兜底跳转浏览器
                          if (ipaUrl.isEmpty) {
                            Navigator.pop(ctx);
                            final webUrl = Uri.parse(htmlUrl);
                            if (await canLaunchUrl(webUrl)) {
                              await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                            }
                            return;
                          }

                          // 开始下载状态
                          setDialogState(() {
                            isDownloading = true;
                            downloadFailed = false;
                            progress = 0.0;
                          });

                          try {
                            final tempDir = await getTemporaryDirectory();
                            // 加上时间戳防止缓存冲突
                            final savePath = '${tempDir.path}/OrbiX_v${newVersion}_${DateTime.now().millisecondsSinceEpoch}.ipa';

                            await Dio().download(
                              ipaUrl,
                              savePath,
                              onReceiveProgress: (received, total) {
                                if (total != -1) {
                                  // 计算进度
                                  final double currentProgress = received / total;
                                  final String pText = "${(currentProgress * 100).toStringAsFixed(1)}%";
                                  final String sText = "${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";

                                  // 更新弹窗 UI
                                  setDialogState(() {
                                    progress = currentProgress;
                                    progressText = pText;
                                    sizeText = sText;
                                  });
                                }
                              },
                            );

                            // 下载完成，先关闭弹窗
                            if (ctx.mounted) Navigator.pop(ctx);

                            // 🌟 核心：拉起 iOS 原生分享面板
                            await Share.shareXFiles(
                              [XFile(savePath)],
                              text: "请选择 TrollStore 巨魔商店进行覆盖安装",
                            );

                          } catch (e) {
                            debugPrint("下载失败: $e");
                            setDialogState(() {
                              downloadFailed = true;
                              sizeText = "网络异常或下载失败，请重试";
                            });
                          }
                        },
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  // 🌟 精美的进度条 UI 组件
  Widget _buildProgressUI(double progress, String progressText, String sizeText, bool failed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        // 进度条主体
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: CupertinoColors.systemGrey5,
            valueColor: AlwaysStoppedAnimation<Color>(
              failed ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 文字信息
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sizeText,
              style: TextStyle(
                fontSize: 12,
                color: failed ? CupertinoColors.destructiveRed : CupertinoColors.systemGrey,
              ),
            ),
            Text(
              progressText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: failed ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hasUpdate ? _showUpdateDialog : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
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
                  border: Border.all(color: const Color(0xFF1C1C1E), width: 2), // 暗黑模式适配
                ),
              ),
            ),
        ],
      ),
    );
  }
}