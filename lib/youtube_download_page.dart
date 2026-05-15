import 'dart:async';
import 'package:flutter/material.dart';
import 'youtube_api_service.dart';

class YouTubeDownloadPage extends StatefulWidget {
  @override
  _YouTubeDownloadPageState createState() => _YouTubeDownloadPageState();
}

class _YouTubeDownloadPageState extends State<YouTubeDownloadPage> {
  final TextEditingController _urlController = TextEditingController();
  
  List<dynamic> _downloadedFiles = [];
  bool _isLoadingFiles = true;

  // 活跃任务状态管理
  String? _activeTaskId;
  int _downloadProgress = 0;
  String _downloadStatus = '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // 获取文件列表
  Future<void> _fetchFiles() async {
    setState(() => _isLoadingFiles = true);
    final files = await YouTubeApiService.getFiles();
    setState(() {
      _downloadedFiles = files;
      _isLoadingFiles = false;
    });
  }

  // 触发下载并开始轮询
  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    FocusScope.of(context).unfocus(); // 收起键盘

    final taskId = await YouTubeApiService.startDownload(url);
    if (taskId != null) {
      setState(() {
        _activeTaskId = taskId;
        _downloadProgress = 0;
        _downloadStatus = '任务已提交...';
      });
      _urlController.clear();
      _startPolling(taskId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交下载任务失败，请检查网络')),
      );
    }
  }

  // 轮询机制：每 2 秒查一次状态
  void _startPolling(String taskId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      final statusData = await YouTubeApiService.getTaskStatus(taskId);
      if (statusData != null) {
        final status = statusData['status'];
        final progress = statusData['progress'] ?? 0;

        setState(() {
          _downloadProgress = progress;
          _downloadStatus = _mapStatusText(status, progress);
        });

        if (status == 'completed' || status == 'failed') {
          timer.cancel();
          setState(() {
            _activeTaskId = null; // 隐藏进度条
          });
          if (status == 'completed') {
            _fetchFiles(); // 下载完刷新列表
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载成功！')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败：${statusData['error']}')),
            );
          }
        }
      }
    });
  }

  String _mapStatusText(String status, int progress) {
    switch (status) {
      case 'processing': return '排队中...';
      case 'downloading': return '正在狂飙下载中 ($progress%)...';
      case 'completed': return '下载完成';
      case 'failed': return '下载失败';
      default: return '解析中...';
    }
  }

  // 删除文件
  Future<void> _deleteFile(String filename) async {
    final success = await YouTubeApiService.deleteFile(filename);
    if (success) {
      _fetchFiles();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除成功')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('视频提取'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 输入框区域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: '粘贴 YouTube 视频链接...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _activeTaskId == null ? _startDownload : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('提取'),
                ),
              ],
            ),
          ),

          // 活跃任务进度条区域
          if (_activeTaskId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_downloadStatus, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _downloadProgress / 100,
                      backgroundColor: Colors.grey[300],
                      color: Colors.blue,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),

          Divider(height: 32),

          // 文件列表区域
          Expanded(
            child: _isLoadingFiles
                ? Center(child: CircularProgressIndicator())
                : _downloadedFiles.isEmpty
                    ? Center(child: Text('暂无下载文件，快去提取吧！', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _fetchFiles,
                        child: ListView.builder(
                          itemCount: _downloadedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _downloadedFiles[index];
                            final sizeInMb = (file['size'] / (1024 * 1024)).toStringAsFixed(2);
                            
                            return Dismissible(
                              key: Key(file['filename']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 20),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                _deleteFile(file['filename']);
                              },
                              child: ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.video_library, color: Colors.blue),
                                ),
                                title: Text(
                                  file['filename'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14),
                                ),
                                subtitle: Text('$sizeInMb MB • ${file['created_at'].toString().split('T')[0]}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.play_circle_fill, color: Colors.blue, size: 32),
                                  onPressed: () {
                                    // 这里拼接完整视频地址，你可以把它传给 Orbix 内置的播放器组件
                                    final videoUrl = YouTubeApiService.getVideoUrl(file['url']);
                                    print('准备播放视频: $videoUrl');
                                    // TODO: 导航到你的视频播放页面
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
