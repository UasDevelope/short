import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/video_model.dart';
import '../../services/enhanced_cache_service.dart';
import '../player/video_player_widget.dart';
import 'dart:io'; // Added for File

class OfflineVideoGalleryScreen extends ConsumerStatefulWidget {
  const OfflineVideoGalleryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OfflineVideoGalleryScreen> createState() => _OfflineVideoGalleryScreenState();
}

class _OfflineVideoGalleryScreenState extends ConsumerState<OfflineVideoGalleryScreen> {
  final EnhancedCacheService _cacheService = EnhancedCacheService();
  List<String> _offlineVideoIds = [];
  List<Map<String, dynamic>> _videoHistory = [];
  Map<String, dynamic> _cacheStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfflineData();
  }

  Future<void> _loadOfflineData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final offlineIds = await _cacheService.getOfflineVideos();
      final history = await _cacheService.getVideoHistory();
      final stats = await _cacheService.getEnhancedCacheStats();

      setState(() {
        _offlineVideoIds = offlineIds;
        _videoHistory = history;
        _cacheStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading offline data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Videos'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfflineData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Offline Stats Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_done, color: Colors.purple, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_offlineVideoIds.length} Videos Available Offline',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Storage: ${_formatBytes(_cacheStats['cacheSizeBytes'] ?? 0)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tabs for different views
                DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Colors.purple,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.purple,
                        tabs: [
                          Tab(text: 'All Videos'),
                          Tab(text: 'Recently Viewed'),
                          Tab(text: 'Downloads'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildAllVideosTab(),
                            _buildRecentlyViewedTab(),
                            _buildDownloadsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAllVideosTab() {
    if (_offlineVideoIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No offline videos',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Pin or download videos from the feed to view them offline.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _offlineVideoIds.length,
      itemBuilder: (context, index) {
        final videoId = _offlineVideoIds[index];
        final historyData = _videoHistory.firstWhere(
          (item) => item['videoId'] == videoId,
          orElse: () => {},
        );

        return _buildVideoCard(videoId, historyData, false);
      },
    );
  }

  Widget _buildRecentlyViewedTab() {
    final recentVideos = _videoHistory.take(10).toList();

    if (recentVideos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recently viewed videos',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recentVideos.length,
      itemBuilder: (context, index) {
        final historyData = recentVideos[index];
        final videoId = historyData['videoId'];

        return _buildVideoCard(videoId, historyData, true);
      },
    );
  }

  Widget _buildDownloadsTab() {
    return FutureBuilder<List<String>>(
      future: _cacheService.getManuallyDownloadedVideos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final downloadedVideos = snapshot.data!;

        if (downloadedVideos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No downloaded videos',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the download button on videos to save them',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: downloadedVideos.length,
          itemBuilder: (context, index) {
            final videoId = downloadedVideos[index];
            return _buildVideoCard(videoId, {}, true);
          },
        );
      },
    );
  }

  Widget _buildVideoCard(String videoId, Map<String, dynamic> historyData, bool showDownloadIcon) {
    final isManuallyDownloaded = showDownloadIcon;
    final lastWatched = historyData['lastWatched'];
    final completionPercent = historyData['completionPercent'] ?? 0.0;
    final viewCount = historyData['viewCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: FutureBuilder<String?>(
          future: _getThumbnailPath(videoId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.file(
                File(snapshot.data!),
                width: 80,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(Icons.play_circle_outline, color: Colors.grey),
              );
            } else {
              return const Icon(Icons.play_circle_outline, color: Colors.grey, size: 48);
            }
          },
        ),
        title: Text(
          'Video $videoId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastWatched != null)
              Text(
                'Last watched: ${_formatDate(lastWatched)}',
              ),
            Text('Completion: ${(completionPercent * 100).toStringAsFixed(0)}%'),
            Text('Views: $viewCount'),
          ],
        ),
        trailing: isManuallyDownloaded
            ? const Icon(Icons.push_pin, color: Colors.purple)
            : null,
        onTap: () async {
          debugPrint('Tapped offline video: $videoId');
          final filePath = await _cacheService.getCachedFilePath(videoId);
          if (await File(filePath).exists()) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Offline Video')),
                  body: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: VideoPlayerWidget(
                        videoId: videoId,
                        videoUrl: filePath,
                        play: true,
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video file not found.')),
              );
            }
          }
        },
      ),
    );
  }

  // Helper to get thumbnail path (for now, just use the video file itself as a placeholder)
  Future<String?> _getThumbnailPath(String videoId) async {
    // In a real app, extract a frame as a thumbnail and cache it
    // For now, just return the video file path
    return await _cacheService.getCachedFilePath(videoId);
  }
} 