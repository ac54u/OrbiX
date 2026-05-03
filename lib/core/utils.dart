import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Utils {
  /// 解析种子名称，提取片名、年份、画质，并支持番号识别路由
  static Map<String, dynamic> cleanFileName(String raw) {
    String quality = 'HD';
    final rawLower = raw.toLowerCase();
    
    // 1. 提前提取画质标签
    if (rawLower.contains('2160p') || rawLower.contains('4k')) {
      quality = '2160p 4K';
    } else if (rawLower.contains('1080p')) {
      quality = '1080p HD';
    }
    if (rawLower.contains('remux')) quality += ' REMUX';
    if (rawLower.contains('web-dl') || rawLower.contains('webrip')) quality += ' WEB';

    // 🌟 2. 番号嗅探逻辑 (针对 START-518, 892OERO-002 等格式)
    // 匹配规则：单词边界 + 2-6位字母 + 可选横杠 + 2-6位数字 + 单词边界
    final codeReg = RegExp(r"\b([a-zA-Z]{2,6}-?\d{2,6})\b");
    final codeMatch = codeReg.firstMatch(raw);

    if (codeMatch != null) {
      // 如果命中了番号格式，直接返回特殊类型，触发私有爬虫路由
      return {
        'type': 'niche_video', 
        'search_key': codeMatch.group(0)!.toUpperCase(), 
        'quality': quality,
        'title': raw, // 备用原始名称
      };
    }

    // 🎬 3. 常规电影提取逻辑 (原来的逻辑)
    final yearReg = RegExp(r"\b(19|20)\d{2}\b");
    final yearMatch = yearReg.firstMatch(raw);
    
    String title = raw;
    String? year;

    if (yearMatch != null) {
      year = yearMatch.group(0);
      title = raw.substring(0, yearMatch.start);
    }

    // 清理标题杂质
    title = title
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r"^\[.*?\]"), "")
        .trim();

    return {
      'type': 'movie', // 显式标记为常规电影
      'title': title.isEmpty ? raw : title, 
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