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
      bufferSize: 1024 * 1024 * 64, 
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

  // 🌟 新增：高级功能状态
  double _playbackRate = 1.0;
  double _subFontSize = 38.0;
  bool _showSubtitles = true;
  String _currentSrtUrl = "";

  // 🌟 新增：AI 翻译状态机
  String _translateStatusText = "正在初始化 AI 引擎...";
  double _translateFakeProgress = 0.05;
  Timer? _translateFakeTimer;

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

  String _getCleanBaseUrl(String raw) {
    if (raw.contains('](')) {
      return raw.split('](').last.replaceAll(')', '').trim();
    }
    final match = RegExp(r'(https?://[0-9a-zA-Z\.\:]+)').firstMatch(raw);
    return match != null ? match.group(0)! : 'http://152.53.131.108:9000';
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
      _autoLoadSubtitle();

      if (mounted) {
        setState(() => _isPreparing = false);
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = "视频加载失败: $e";
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _autoLoadSubtitle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawBaseUrl = prefs.getString('api_base_url') ?? 'http://152.53.131.108:9000';
      final baseUrl = _getCleanBaseUrl(rawBaseUrl);
      final srtUrl = "$baseUrl/videos/${Uri.encodeComponent(widget.title.replaceAll(".mp4", ""))}.vtt";
      
      final response = await http.head(Uri.parse(srtUrl));
      if (response.statusCode == 200 || response.statusCode == 206) {
        _currentSrtUrl = srtUrl;
        await player.setSubtitleTrack(SubtitleTrack.uri(srtUrl, title: 'DeepSeek 中文', language: 'zh'));
      }
    } catch (e) {
      debugPrint("探测字幕失败: $e");
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
      if (mounted && !_isDraggingProgress && !_isTranslating) {
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

  // 🌟 核心升级：优雅的 AI 翻译进度弹窗
  Future<void> _triggerDeepSeekTranslation() async {
    setState(() {
      _isTranslating = true;
      _translateFakeProgress = 0.05;
      _translateStatusText = "正在嗅探音频轨道...";
    });
    
    _hideTimer?.cancel(); // 翻译期间保持面板亮起

    // 🌟 启动前端状态机模拟器，安抚用户情绪
    int step = 0;
    _translateFakeTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        step++;
        if (_translateFakeProgress < 0.9) {
          _translateFakeProgress += 0.05; 
        }
        switch (step) {
          case 1: _translateStatusText = "正在提取本地高音质流..."; break;
          case 2: _translateStatusText = "正在唤醒 Whisper 引擎..."; break;
          case 4: _translateStatusText = "Whisper 正在高强度听写对白..."; break;
          case 10: _translateStatusText = "听写完成，正在连线 DeepSeek 大模型..."; break;
          case 12: _translateStatusText = "DeepSeek 正在进行深度语义翻译..."; break;
          case 25: _translateStatusText = "大模型运算中，请稍候..."; break;
        }
      });
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawBaseUrl = prefs.getString('api_base_url') ?? 'http://152.53.131.108:9000';
      final baseUrl = _getCleanBaseUrl(rawBaseUrl);
      final requestUrl = "$baseUrl/api/subtitle/generate?title=${Uri.encodeComponent(widget.title)}";
      
      final response = await http.get(Uri.parse(requestUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _translateFakeProgress = 1.0;
            _translateStatusText = "✅ 翻译完成！正在挂载字幕...";
          });
          await Future.delayed(const Duration(milliseconds: 800));
          
          final srtUrl = baseUrl + data['url'];
          _currentSrtUrl = srtUrl;
          if (_showSubtitles) {
            await player.setSubtitleTrack(SubtitleTrack.uri(srtUrl, title: 'DeepSeek 中文', language: 'zh'));
          }
          Utils.showToast(data['cached'] == true ? "⚡ 本地已有缓存翻译，秒级挂载！" : "✅ 智能挂载完毕！");
        } else {
          Utils.showToast("❌ 翻译失败: ${data['detail']}");
        }
      } else {
        Utils.showToast("❌ 请求失败，可能无官方字幕且本地处理异常");
      }
    } catch (e) {
      Utils.showToast("❌ 网络通道异常: $e");
    } finally {
      _translateFakeTimer?.cancel();
      if (mounted) {
        setState(() => _isTranslating = false);
        _startHideTimer();
      }
    }
  }

  // 🌟 新增：高级设置控制台 (倍速、字幕大小)
  void _showSettingsPanel() {
    _hideTimer?.cancel();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("播放器高级设置", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // 倍速控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("播放倍速", style: TextStyle(color: Colors.white70)),
                    CupertinoSlidingSegmentedControl<double>(
                      backgroundColor: Colors.white10,
                      thumbColor: Colors.white30,
                      groupValue: _playbackRate,
                      children: const {
                        1.0: Text("1.0x", style: TextStyle(color: Colors.white)),
                        1.25: Text("1.25x", style: TextStyle(color: Colors.white)),
                        1.5: Text("1.5x", style: TextStyle(color: Colors.white)),
                        2.0: Text("2.0x", style: TextStyle(color: Colors.white)),
                      },
                      onValueChanged: (v) {
                        if (v != null) {
                          setModalState(() => _playbackRate = v);
                          setState(() => _playbackRate = v);
                          player.setRate(v);
                          HapticFeedback.selectionClick();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 字幕大小控制
                Row(
                  children: [
                    const Text("字幕大小", style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CupertinoSlider(
                        value: _subFontSize,
                        min: 16.0,
                        max: 60.0,
                        activeColor: CupertinoColors.activeBlue,
                        onChanged: (v) {
                          setModalState(() => _subFontSize = v);
                          setState(() => _subFontSize = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text("${_subFontSize.toInt()}", textAlign: TextAlign.right, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 字幕开关
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("显示字幕", style: TextStyle(color: Colors.white70)),
                    CupertinoSwitch(
                      value: _showSubtitles,
                      onChanged: (v) {
                        setModalState(() => _showSubtitles = v);
                        setState(() => _showSubtitles = v);
                        if (v && _currentSrtUrl.isNotEmpty) {
                          player.setSubtitleTrack(SubtitleTrack.uri(_currentSrtUrl, title: 'DeepSeek 中文', language: 'zh'));
                        } else {
                          player.setSubtitleTrack(SubtitleTrack.no());
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }
      ),
    ).then((_) => _startHideTimer());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _osdHideTimer?.cancel();
    _translateFakeTimer?.cancel();
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
              controls: NoVideoControls, 
              // 🌟 响应式字幕配置：跟随设置面板的实时数值！
              subtitleViewConfiguration: SubtitleViewConfiguration(
                style: TextStyle(
                  fontSize: _subFontSize, 
                  color: const Color(0xFFFFE500),
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(offset: Offset(3, 3), blurRadius: 6, color: Colors.black),
                    Shadow(offset: Offset(-2, -2), blurRadius: 4, color: Colors.black),
                  ],
                ),
                textAlign: TextAlign.center,
                padding: const EdgeInsets.only(bottom: 40), 
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
              onDoubleTapDown: (details) async {
                if (_isLocked) return;
                HapticFeedback.lightImpact();
                final screenWidth = MediaQuery.of(context).size.width;
                final target = details.globalPosition.dx < screenWidth / 2
                    ? player.state.position - const Duration(seconds: 10)
                    : player.state.position + const Duration(seconds: 10);
                await player.seek(target);
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

          // 🌟 沉浸式 AI 翻译面板
          if (_isTranslating)
            Positioned(
              top: 90,
              right: 20,
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(CupertinoIcons.sparkles, color: CupertinoColors.systemYellow, size: 16),
                        SizedBox(width: 8),
                        Text("AI 翻译引擎运行中", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _translateFakeProgress,
                        backgroundColor: Colors.white10,
                        color: CupertinoColors.activeBlue,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _translateStatusText,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    )
                  ],
                ),
              ),
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
    if (_hasError) return const SizedBox.shrink(); // 错误提示已简化
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (context, snapshot) {
        final isBuffering = snapshot.data ?? true;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isBuffering
              ? Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: const CupertinoActivityIndicator(radius: 16, color: Colors.white),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.playOrPause();
                    _startHideTimer();
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(18),
                    child: StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, playing) => Icon(
                        playing.data == true ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: Colors.white, size: 52,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 90, 
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
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
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 🌟 顶部工具栏扩展：设置按钮 + 翻译按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showSettingsPanel,
            child: const Icon(CupertinoIcons.gear_alt_fill, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isTranslating ? null : _triggerDeepSeekTranslation,
            child: Icon(
              CupertinoIcons.captions_bubble_fill, 
              color: _isTranslating ? Colors.white30 : Colors.white, 
              size: 28
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
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
              Text(_formatDuration(Duration(seconds: currentSliderValue.toInt())), style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Courier')),
              Expanded(
                child: CupertinoSlider(
                  value: currentSliderValue.clamp(0.0, maxSliderValue),
                  max: maxSliderValue,
                  activeColor: Colors.redAccent, 
                  thumbColor: Colors.white,
                  onChangeStart: (v) {
                    setState(() { _isDraggingProgress = true; _dragProgressValue = v; });
                    _hideTimer?.cancel();
                    player.pause();
                  },
                  onChanged: (v) => setState(() => _dragProgressValue = v),
                  onChangeEnd: (v) async {
                    HapticFeedback.selectionClick();
                    await player.seek(Duration(seconds: v.toInt()));
                    player.play();
                    setState(() => _isDraggingProgress = false);
                    _startHideTimer();
                  },
                ),
              ),
              Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Courier')),
              const SizedBox(width: 20),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_videoFit == BoxFit.contain) _videoFit = BoxFit.cover;
                    else if (_videoFit == BoxFit.cover) _videoFit = BoxFit.fill;
                    else _videoFit = BoxFit.contain;
                  });
                  _startHideTimer();
                },
                child: Icon(
                  _videoFit == BoxFit.contain ? CupertinoIcons.rectangle_expand_vertical : CupertinoIcons.rectangle_arrow_up_right_arrow_down_left,
                  color: Colors.white, size: 22,
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