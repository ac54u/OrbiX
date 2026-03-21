import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 需要在 pubspec.yaml 中添加 intl 依赖
import '../services/arr_api_service.dart';

class UpcomingMediaScreen extends StatefulWidget {
  const UpcomingMediaScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingMediaScreen> createState() => _UpcomingMediaScreenState();
}

class _UpcomingMediaScreenState extends State<UpcomingMediaScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);
    final items = await ArrApiService.getUpcomingCalendar();
    setState(() {
      _mediaItems = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未来 7 天日历', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendar,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
              ? const Center(child: Text("最近一周没有新媒体哦"))
              : RefreshIndicator(
                  onRefresh: _loadCalendar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _mediaItems.length,
                    itemBuilder: (context, index) {
                      final item = _mediaItems[index];
                      // 格式化日期：例如 "12月25日 20:00"
                      final dateStr = DateFormat('MM月dd日 HH:mm').format(item.date);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: item.posterUrl.isNotEmpty
                                ? Image.network(
                                    item.posterUrl,
                                    width: 50,
                                    height: 75,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(width: 50, color: Colors.grey[800], child: const Icon(Icons.movie)),
                                  )
                                : Container(width: 50, color: Colors.grey[800], child: const Icon(Icons.movie)),
                          ),
                          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.type == 'Movie' ? Colors.blue.withOpacity(0.2) : Colors.purple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(item.type == 'Movie' ? '电影' : '剧集', style: TextStyle(fontSize: 12, color: item.type == 'Movie' ? Colors.blue : Colors.purple)),
                                ),
                                const SizedBox(width: 8),
                                Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.status == '已下载' ? Icons.check_circle : Icons.access_time,
                                color: item.status == '已下载' ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(height: 4),
                              Text(item.status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}