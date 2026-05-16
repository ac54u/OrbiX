import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const PlayerScreen({super.key, required this.streamUrl, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 1024 * 1024 * 64, // 64MB 缓冲区，防卡顿
    ),
  );
  late final controller = VideoController(player);

  bool _hasError = false;
  String _errorMsg = '';
  bool _isPreparing = true;
  bool _isTranslating = false; 

  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  BoxFit _videoFit = BoxFit.contain;
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  double _volume = 50.0;
  double _brightness = 0.5;
  String _osdType = '';
  bool _showOsd = false;
  Timer? _osdHideTimer;
  double _startDragValue = 0.0;
  bool _isLeftSideDrag = true;
  int _lastHapticLevel = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = error.toString();
          _isPreparing = false;
        });
      }
    });

    _initBrightness();
    _initializeUniversalPlayer();
  }

  Future<void> _initializeUniversalPlayer() async {
    try {
      await player.open(Media(
        widget.streamUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
      ));

      player.setVolume(_volume);
      if (mounted) {
        setState(() => _isPreparing = false);
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = "加载失败: $e";
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint("获取亮度失败: $e");
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDraggingProgress) {
        setState(() => _showControls = false);
      }
    });
  }

  void _handleScreenTap() {
    if (_isLocked) {
      setState(() => _showControls = true);
      _startHideTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _showOsdIndicator(String type) {
    setState(() {
      _osdType = type;
      _showOsd = true;
    });
    _osdHideTimer?.cancel();
    _osdHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showOsd = false);
    });
  }

  // 🌟 核心：直连后端 DeepSeek 翻译接口，传递干净的 title
  Future<void> _triggerDeepSeekTranslation() async {
    setState(() => _isTranslating = true);
    Utils.showToast("🚀 正在呼叫后端 DeepSeek 提取并翻译...");

    try {
      final prefs = await SharedPreferences.getInstance();
      // 这里确保不会有 Markdown 格式混入，直接取配置或默认 IP
      final baseUrl = prefs.getString('api_base_url') ?? 'http://152.53.131.108:9000';
      
      // 传递视频标题，让后端去搜索原视频
      final requestUrl = "$baseUrl/api/subtitle/generate?title=${Uri.encodeComponent(widget.title)}";
      
      final response = await http.get(Uri.parse(requestUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final srtUrl = baseUrl + data['url'];
          Utils.showToast("✅ AI 翻译完成！正在挂载...");
          await player.setSubtitleTrack(SubtitleTrack.uri(srtUrl, title: 'DeepSeek 中文', language: 'zh'));
        } else {
          Utils.showToast("❌ 翻译失败: ${data['detail']}");
        }
      } else {
        Utils.showToast("❌ 请求失败，可能未找到原视频英文字幕");
      }
    } catch (e) {
      Utils.showToast("❌ 网络错误: $e");
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _osdHideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness().resetScreenBrightness();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Video(
              controller: controller,
              fit: _videoFit,
              fill: Colors.transparent,
              // 🌟 Netflix 样式黄字黑边字幕，强制沉底
              subtitleViewConfiguration: const SubtitleViewConfiguration(
                style: TextStyle(
                  fontSize: 26, 
                  color: Color(0xFFFFE500),
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black),
                    Shadow(offset: Offset(-1, -1), blurRadius: 2, color: Colors.black),
                  ],
                ),
                textAlign: TextAlign.center,
                padding: EdgeInsets.only(bottom: 30), 
              ),
            ),
          ),

          if (_isPreparing && !_hasError)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(radius: 20, color: Colors.white),
                    SizedBox(height: 16),
                    Text("智能嗅探多媒体源...", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),

          if (!_isPreparing)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleScreenTap,
              onDoubleTapDown: (details) {
                if (_isLocked) return;
                HapticFeedback.lightImpact();
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < screenWidth / 2) {
                  player.seek(player.state.position - const Duration(seconds: 10));
                } else {
                  player.seek(player.state.position + const Duration(seconds: 10));
                }
                _showOsdIndicator('seek');
              },
              onVerticalDragStart: (details) {
                if (_isLocked) return;
                final screenWidth = MediaQuery.of(context).size.width;
                _isLeftSideDrag = details.globalPosition.dx < screenWidth / 2;
                _startDragValue = _isLeftSideDrag ? _brightness : (_volume / 100.0);
                _lastHapticLevel = (_startDragValue * 20).toInt();
              },
              onVerticalDragUpdate: (details) {
                if (_isLocked) return;
                final screenHeight = MediaQuery.of(context).size.height;
                final delta = -details.primaryDelta! / (screenHeight * 0.8);

                double newValue = (_startDragValue + delta).clamp(0.0, 1.0);
                _startDragValue = newValue;

                int currentLevel = (newValue * 20).toInt();
                if (currentLevel != _lastHapticLevel) {
                  HapticFeedback.selectionClick();
                  _lastHapticLevel = currentLevel;
                }

                setState(() {
                  if (_isLeftSideDrag) {
                    _brightness = newValue;
                    ScreenBrightness().setScreenBrightness(_brightness);
                    _showOsdIndicator('brightness');
                  } else {
                    _volume = newValue * 100;
                    player.setVolume(_volume);
                    _showOsdIndicator('volume');
                  }
                });
              },
            ),

          Center(
            child: AnimatedOpacity(
              opacity: _showOsd ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getOsdIcon(), color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _osdType == 'volume' ? _volume / 100.0 : _brightness,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (!_isPreparing)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    if (!_isLocked) ...[
                      Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
                      Center(child: _buildCenterPlayButton()),
                      Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
                    ],
                    Positioned(
                      left: 40,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _isLocked = !_isLocked;
                              if (!_isLocked) _startHideTimer();
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isLocked ? Colors.redAccent.withOpacity(0.8) : Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isLocked ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open_fill,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getOsdIcon() {
    if (_osdType == 'volume') {
      if (_volume == 0) return CupertinoIcons.volume_mute;
      if (_volume < 50) return CupertinoIcons.volume_down;
      return CupertinoIcons.volume_up;
    } else if (_osdType == 'brightness') {
      return CupertinoIcons.brightness;
    }
    return CupertinoIcons.play_fill;
  }

  Widget _buildCenterPlayButton() {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.redAccent, size: 36),
            const SizedBox(height: 12),
            const Text("流媒体加载失败", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              width: 250,
              child: Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (context, snapshot) {
        final isBuffering = snapshot.data ?? true;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isBuffering
              ? Container(
                  key: const ValueKey('buffering'),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CupertinoActivityIndicator(radius: 16, color: Colors.white),
                      SizedBox(height: 14),
                      Text(
                        "正在缓冲...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : CupertinoButton(
                  key: const ValueKey('play_btn'),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.playOrPause();
                    _startHideTimer();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, playing) => Icon(
                        playing.data == true ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // 🌟 纯净黑色渐变顶部栏
  Widget _buildTopBar() {
    return Container(
      height: 90, 
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent], 
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)], 
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isTranslating ? null : _triggerDeepSeekTranslation,
            child: _isTranslating
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Icon(CupertinoIcons.captions_bubble_fill, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // 🌟 纯净黑色渐变底部栏
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: StreamBuilder(
        stream: player.stream.position,
        builder: (context, pos) {
          final realPosition = pos.data ?? Duration.zero;
          final duration = player.state.duration;

          final currentSliderValue = _isDraggingProgress ? _dragProgressValue : realPosition.inSeconds.toDouble();
          final maxSliderValue = duration.inSeconds.toDouble().clamp(0.01, double.infinity);

          return Row(
            children: [
              Text(_formatDuration(Duration(seconds: currentSliderValue.toInt())),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Courier')),
              Expanded(
                child: CupertinoSlider(
                  value: currentSliderValue.clamp(0.0, maxSliderValue),
                  max: maxSliderValue,
                  activeColor: Colors.redAccent, 
                  thumbColor: Colors.white,
                  onChangeStart: (v) {
                    setState(() {
                      _isDraggingProgress = true;
                      _dragProgressValue = v;
                    });
                    _hideTimer?.cancel();
                  },
                  onChanged: (v) => setState(() => _dragProgressValue = v),
                  onChangeEnd: (v) {
                    HapticFeedback.selectionClick();
                    player.seek(Duration(seconds: v.toInt()));
                    setState(() => _isDraggingProgress = false);
                    _startHideTimer();
                  },
                ),
              ),
              Text(_formatDuration(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Courier')),
              const SizedBox(width: 20),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_videoFit == BoxFit.contain) {
                      _videoFit = BoxFit.cover;
                    } else if (_videoFit == BoxFit.cover) {
                      _videoFit = BoxFit.fill;
                    } else {
                      _videoFit = BoxFit.contain;
                    }
                  });
                  _startHideTimer();
                },
                child: Icon(
                  _videoFit == BoxFit.contain
                      ? CupertinoIcons.rectangle_expand_vertical
                      : CupertinoIcons.rectangle_arrow_up_right_arrow_down_left,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
