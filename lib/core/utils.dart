import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Utils {
  static Map<String, dynamic> cleanFileName(String raw) {
    String quality = 'HD';
    final rawLower = raw.toLowerCase();
    
    // 1. 提取画质标签
    if (rawLower.contains('2160p') || rawLower.contains('4k')) {
      quality = '2160p 4K';
    } else if (rawLower.contains('1080p')) {
      quality = '1080p HD';
    }
    if (rawLower.contains('remux')) quality += ' REMUX';
    if (rawLower.contains('web-dl') || rawLower.contains('webrip')) quality += ' WEB';

    // 2. 电影年份提取 (优先判断)
    final yearReg = RegExp(r"\b(19|20)\d{2}\b");
    final yearMatch = yearReg.firstMatch(raw);
    
    String title = raw;
    String? year;

    // 🌟 核心逻辑修复：如果找到了年份，坚决走电影模式，防止误伤 HDR10 等标签
    if (yearMatch != null) {
      year = yearMatch.group(0);
      title = raw.substring(0, yearMatch.start);
      
      return {
        'type': 'movie',
        'title': _finalizeTitle(title, raw),
        'year': year,
        'quality': quality,
      };
    }

    // 3. 番号嗅探逻辑 (仅在没有年份的情况下执行)
    // 排除掉常见的干扰项如 HDR10, H264 等
    final blacklist = ['HDR10', 'H264', 'H265', 'X264', 'X265', 'DV', 'PROPER', 'IMAX'];
    final codeReg = RegExp(r"\b([a-zA-Z]{2,6}-?\d{2,6})\b");
    final codeMatch = codeReg.firstMatch(raw);

    if (codeMatch != null) {
      String code = codeMatch.group(0)!.toUpperCase();
      // 如果命中的码不在黑名单里，才认为是番号
      if (!blacklist.contains(code)) {
        return {
          'type': 'niche_video',
          'search_key': code,
          'quality': quality,
          'title': raw,
        };
      }
    }

    // 4. 默认回退到电影模式
    return {
      'type': 'movie',
      'title': _finalizeTitle(title, raw),
      'year': null,
      'quality': quality,
    };
  }

  // 辅助函数：清洗标题杂质
  static String _finalizeTitle(String title, String raw) {
    String result = title
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r"^\[.*?\]"), "")
        .trim();
    return result.isEmpty ? raw : result;
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