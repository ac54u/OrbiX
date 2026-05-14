import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';

class AddTorrentSheet extends StatefulWidget {
  const AddTorrentSheet({super.key});

  @override
  State<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<AddTorrentSheet> {
  int _groupValue = 0; // 0: 链接, 1: 文件
  final _urlController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _selectedFilePath;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // 选择 .torrent 文件
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  // 提交添加请求 (🌟 已加入 YouTube 智能分流)
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // 自动读取设置里的默认路径
    final prefs = await SharedPreferences.getInstance();
    String? defaultPath = prefs.getString('default_path');

    // 如果设置里是空的，就传 null (让 qBittorrent 使用它自己的默认配置)
    if (defaultPath != null && defaultPath.trim().isEmpty) {
      defaultPath = null;
    }

    bool success = false;
    final cat = _categoryController.text.isNotEmpty ? _categoryController.text : null;
    final tags = _tagsController.text.isNotEmpty ? _tagsController.text : null;

    if (_groupValue == 0) {
      // --- 添加链接 (磁力/URL/YouTube) ---
      final url = _urlController.text.trim();
      if (url.isEmpty) {
         Utils.showToast("请输入链接");
         setState(() => _isSubmitting = false);
         return;
      }

      // 🌟 核心智能分流逻辑
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        Utils.showToast("正在解析 YouTube 视频...");
        final errorMsg = await ApiService.addYoutubeTask(url);
        if (errorMsg == null) {
          success = true;
        } else {
          // ⚠️ 把真实的报错弹出来给大哥看
          Utils.showToast("解析失败: $errorMsg");
          setState(() => _isSubmitting = false);
          return;
        }
      } else {
        Utils.showToast("正在提交下载任务...");
        success = await ApiService.addTorrent(
          url,
          savePath: defaultPath,
          category: cat,
          tags: tags,
        );
      }

    } else {
      // --- 添加文件 (.torrent) ---
      if (_selectedFilePath == null) {
        Utils.showToast("请选择文件");
        setState(() => _isSubmitting = false);
        return;
      }

      success = await ApiService.addTorrentFile(
        _selectedFilePath!,
        savePath: defaultPath,
        category: cat,
        tags: tags,
      );
    }

    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.heavyImpact();
      String msg = "添加成功";
      if (defaultPath != null && !(_urlController.text.contains('youtube.com') || _urlController.text.contains('youtu.be'))) {
        final folderName = defaultPath.split('/').last;
        msg += " (存入: $folderName)";
      }

      Utils.showToast(msg);
      if (mounted) Navigator.pop(context);
    } else {
      Utils.showToast("添加失败，请检查网络或链接");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? kBgColorDark : kBgColorLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部导航栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text("取消"),
                  onPressed: () => Navigator.pop(context),
                ),
                Text("添加任务", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor)),
                _isSubmitting
                    ? const CupertinoActivityIndicator()
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _submit,
                        child: const Text("添加", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 切换 链接/文件
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _groupValue,
                      children: const {
                        0: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("链接")),
                        1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("文件")),
                      },
                      onValueChanged: (v) {
                        setState(() => _groupValue = v ?? 0);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 内容区域
                  if (_groupValue == 0) ...[
                    // --- 链接输入 ---
                    const Text("种子或 YouTube 链接", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _urlController,
                      placeholder: "磁力链接 / HTTP种子 / YouTube",
                      maxLines: 4,
                      autofocus: true,
                      style: TextStyle(color: textColor),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.doc_on_clipboard),
                        onPressed: () async {
                           final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                           if (data != null && data.text != null) {
                             setState(() {
                               _urlController.text = data.text!;
                             });
                             HapticFeedback.selectionClick();
                           }
                        },
                      ),
                    ),
                  ] else ...[
                    // --- 文件选择 ---
                    const Text("种子文件", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedFilePath == null ? CupertinoIcons.add : CupertinoIcons.doc_fill,
                              size: 32,
                              color: kPrimaryColor,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _selectedFilePath == null ? "点击选择 .torrent 文件" : _selectedFilePath!.split('/').last,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _selectedFilePath == null ? Colors.grey : textColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text("可选设置 (仅对种子生效)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),

                  // 选项组
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildInputRow("分类", "点击输入", _categoryController, isLast: false, textColor: textColor),
                        _buildInputRow("标签", "多个标签用逗号分隔", _tagsController, isLast: true, textColor: textColor),
                      ],
                    ),
                  ),

                  // 底部提示
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.info_circle, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      FutureBuilder<SharedPreferences>(
                        future: SharedPreferences.getInstance(),
                        builder: (context, snapshot) {
                           String path = "默认路径";
                           if (snapshot.hasData) {
                             path = snapshot.data!.getString('default_path') ?? "默认路径";
                             if (path.length > 25) path = "...${path.substring(path.length - 25)}";
                           }
                           return Text(
                             "BT将保存到: $path",
                             style: const TextStyle(fontSize: 12, color: Colors.grey),
                           );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 修复：将 border 改为 decoration: null
  Widget _buildInputRow(String label, String placeholder, TextEditingController controller, {required bool isLast, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              decoration: null, // ✅ 这里改好了，去掉了边框
              textAlign: TextAlign.right,
              placeholderStyle: const TextStyle(color: Colors.grey),
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}