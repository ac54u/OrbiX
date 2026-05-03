import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Utils {
  /// 解析种子名称，提取片名、年份和画质
  static Map<String, dynamic> cleanFileName(String raw) {
    String quality = 'HD';
    final rawLower = raw.toLowerCase();
    
    // 提前提取画质标签
    if (rawLower.contains('2160p') || rawLower.contains('4k')) {
      quality = '2160p 4K';
    } else if (rawLower.contains('1080p')) {
      quality = '1080p HD';
    }
    if (rawLower.contains('remux')) quality += ' REMUX';
    if (rawLower.contains('web-dl') || rawLower.contains('webrip')) quality += ' WEB';

    // 提取年份 (\b 边界防止误伤 1920x1080)
    final yearReg = RegExp(r"\b(19|20)\d{2}\b");
    final yearMatch = yearReg.firstMatch(raw);
    
    String title = raw;
    String? year;

    if (yearMatch != null) {
      year = yearMatch.group(0);
      title = raw.substring(0, yearMatch.start);
    }

    // 清理标题
    title = title
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r"^\[.*?\]"), "")
        .trim();

    return {
      'title': title, 
      'year': year,
      'quality': quality,
    };
  }

  static String formatBytes(dynamic b) {
    if (b is! num || b <= 0) return "0 B";
    const s = ["B", "KB", "MB", "GB", "TB", "PB"];
    int i = (log(b) / log(1024)).floor();
    if (i >= s.length) i = s.length - 1;
    return "${(b / pow(1024, i)).toStringAsFixed(1)} ${s[i]}";
  }

  static bool isValidHash(String? h) {
    if (h == null) return false;
    return RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(h);
  }

  static void showToast(String msg) {
    HapticFeedback.mediumImpact();
    Fluttertoast.showToast(
      msg: msg,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }
}