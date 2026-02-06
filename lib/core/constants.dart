import 'package:flutter/material.dart';

// --- 全局状态 ---
final ValueNotifier<bool> themeNotifier = ValueNotifier(false);

// --- 全局常量 ---
const Color kPrimaryColor = Color(0xFF007AFF);
const Color kBgColorLight = Color(0xFFF2F2F7); // 您原先的浅色背景
const Color kBgColorDark = Color(0xFF000000);  // ✅ 您定义的纯黑深色背景
const Color kCardColorLight = Colors.white;
const Color kCardColorDark = Color(0xFF1C1C1E); // ✅ 您定义的深灰卡片/导航栏色
const String kDefaultTmdbKey = "43b4b5765952327c5932292f76332766";

// 动态颜色 Getter
Color get kBgColor => themeNotifier.value ? kBgColorDark : kBgColorLight;
Color get kCardColor => themeNotifier.value ? kCardColorDark : kCardColorLight;

final List<BoxShadow> kMinimalShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: Colors.black.withOpacity(0.02),
    blurRadius: 2,
    offset: const Offset(0, 1),
  ),
];