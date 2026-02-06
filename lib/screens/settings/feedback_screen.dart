import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_descCtrl.text.isEmpty) {
      Utils.showToast("请至少填写问题描述");
      return;
    }
    
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      final id = await Sentry.captureMessage(
        "用户反馈: ${_descCtrl.text.length > 10 ? _descCtrl.text.substring(0, 10) : _descCtrl.text}...",
        level: SentryLevel.info,
      );

      final feedback = SentryUserFeedback(
        eventId: id,
        name: _nameCtrl.text.isEmpty ? "匿名用户" : _nameCtrl.text,
        email: _emailCtrl.text.isEmpty ? "no-email@example.com" : _emailCtrl.text,
        comments: _descCtrl.text,
      );

      await Sentry.captureUserFeedback(feedback);

      if (mounted) {
        Utils.showToast("🚀 反馈已发送，感谢您的建议！");
        Navigator.pop(context);
      }
    } catch (e) {
      Utils.showToast("❌ 发送失败，请稍后再试");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return CupertinoPageScaffold(
          backgroundColor: isDark ? kBgColorDark : kBgColorLight,
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              "意见反馈",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: isDark ? kBgColorDark : kBgColorLight,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const CupertinoActivityIndicator()
                  : const Text("发送", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(top: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "遇到问题或有新功能建议？请告诉我们。",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  backgroundColor: isDark ? kBgColorDark : kBgColorLight,
                  decoration: BoxDecoration(
                    color: isDark ? kCardColorDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  children: [
                    CupertinoListTile(
                      backgroundColor: isDark ? kCardColorDark : Colors.white,
                      leading: const Icon(CupertinoIcons.person_solid, color: Colors.grey),
                      title: CupertinoTextField(
                        controller: _nameCtrl,
                        placeholder: "您的称呼 (选填)",
                        decoration: null,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        placeholderStyle: const TextStyle(color: Colors.grey),
                        cursorColor: kPrimaryColor,
                      ),
                    ),
                    CupertinoListTile(
                      backgroundColor: isDark ? kCardColorDark : Colors.white,
                      leading: const Icon(CupertinoIcons.mail_solid, color: Colors.grey),
                      title: CupertinoTextField(
                        controller: _emailCtrl,
                        placeholder: "联系邮箱 (选填)",
                        keyboardType: TextInputType.emailAddress,
                        decoration: null,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        placeholderStyle: const TextStyle(color: Colors.grey),
                        cursorColor: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CupertinoListSection.insetGrouped(
                  backgroundColor: isDark ? kBgColorDark : kBgColorLight,
                  decoration: BoxDecoration(
                    color: isDark ? kCardColorDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  header: const Text("描述"),
                  children: [
                    Container(
                      height: 150,
                      padding: const EdgeInsets.all(12),
                      color: isDark ? kCardColorDark : Colors.white,
                      child: CupertinoTextField(
                        controller: _descCtrl,
                        placeholder: "请详细描述您遇到的 Bug 或建议...",
                        maxLines: 10,
                        decoration: null,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black, 
                          height: 1.4,
                        ),
                        placeholderStyle: const TextStyle(color: Colors.grey),
                        cursorColor: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "我们会仔细阅读每一条反馈，但无法逐一回复，敬请谅解。",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}