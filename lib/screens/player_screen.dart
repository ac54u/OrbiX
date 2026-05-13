import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:ui';
import 'package:screen_brightness/screen_brightness.dart'; // 硬件亮度控制

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const PlayerScreen({super.key, required this.streamUrl, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final player = Player();
  late final controller = VideoController(player);

  // UI 状态
  bool _showControls = true;
  bool _isLocked = false; // 防误触锁
  Timer? _hideTimer;

  // 画面比例
  BoxFit _videoFit = BoxFit.contain;

  // 拖拽进度条防卡顿状态
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;

  // 全局手势状态 (亮度/音量)
  double _volume = 50.0;
  double _brightness = 0.5;
  String _osdType = ''; // 'volume' 或 'brightness'
  bool _showOsd = false;
  Timer? _osdHideTimer;

  // 手势计算缓存
  double _startDragValue = 0.0;
  bool _isLeftSideDrag = true;
  int _lastHapticLevel = 0; // 用于控制震动频率

  @override
  void initState() {
    super.initState();
    // 强制横屏，沉浸式体验
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      SystemOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    player.open(Media(widget.streamUrl));
    player.setVolume(_volume);

    // 获取当前真实系统亮度
    _initBrightness();
    _startHideTimer();
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint("获取亮度失败: $e");
    }
  }

  // 重置 UI 隐藏定时器
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDraggingProgress) {
        setState(() => _showControls = false);
      }
    });
  }

  // 点击屏幕逻辑
  void _handleScreenTap() {
    if (_isLocked) {
      // 锁屏状态下，点击只短暂呼出解锁按钮
      setState(() => _showControls = true);
      _startHideTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  // 呼出居中 OSD 提示
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    _osdHideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness().resetScreenBrightness(); // 退出时恢复系统亮度
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // 1. 底层视频渲染
          Center(
            child: Video(
              controller: controller,
              fit: _videoFit,
              fill: Colors.transparent,
            ),
          ),

          // 2. 全局手势交互层 (HUD)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _handleScreenTap,
            onDoubleTapDown: (details) {
              if (_isLocked) return;
              HapticFeedback.lightImpact(); // 双击震动反馈
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
              _lastHapticLevel = (_startDragValue * 20).toInt(); // 分20个震动档位
            },
            onVerticalDragUpdate: (details) {
              if (_isLocked) return;

              // 根据屏幕高度计算阻尼系数，让滑动极其丝滑
              final screenHeight = MediaQuery.of(context).size.height;
              // 负数是因为向上滑动 deltaY 为负，但我们要增加数值
              final delta = -details.primaryDelta! / (screenHeight * 0.8);

              double newValue = (_startDragValue + delta).clamp(0.0, 1.0);
              _startDragValue = newValue; // 累加

              // 细腻的齿轮震动感 (每变化 5% 震动一次)
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

          // 3. 屏幕中心 OSD 提示 (HUD)
          Center(
            child: AnimatedOpacity(
              opacity: _showOsd ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
                  ],
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

          // 4. UI 控件与防误触锁
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                children: [
                  // 非锁屏时显示的常规 UI
                  if (!_isLocked) ...[
                    Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
                    Center(child: _buildCenterPlayButton()),
                    Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
                  ],

                  // 锁屏按钮 (浮动在左侧居中)
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
                            // 解锁后保持 UI 几秒钟
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

  // 动态获取 OSD 图标
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

  // --- UI 组件封装 ---

  Widget _buildCenterPlayButton() {
    return CupertinoButton(
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
        child: StreamBuilder(
          stream: player.stream.playing,
          builder: (context, playing) => Icon(
            playing.data == true ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            color: Colors.white,
            size: 52,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
          child: StreamBuilder(
            stream: player.stream.position,
            builder: (context, pos) {
              final realPosition = pos.data ?? Duration.zero;
              final duration = player.state.duration;

              // 进度条防抖处理
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
                      activeColor: Colors.white,
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
        ),
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