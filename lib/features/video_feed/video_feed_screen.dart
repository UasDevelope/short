import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/video_model.dart';
import 'video_feed_provider.dart';
import 'video_feed_controller.dart';
import '../player/video_player_widget.dart';
import '../../services/video_cache_service.dart';
import '../upload/upload_screen.dart';
import '../../services/auth_service.dart';

class VideoFeedScreen extends ConsumerStatefulWidget {
  const VideoFeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> {
  bool _isOffline = false;
  List<String> _cachedIds = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadCachedIds();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  Future<void> _loadCachedIds() async {
    final ids = await VideoCacheService().getCachedVideoIds();
    setState(() {
      _cachedIds = ids;
    });
  }

  Future<void> _refreshVideos() async {
    // Refresh the video feed
    ref.invalidate(videoFeedProvider);
    await _loadCachedIds();
  }

  @override
  Widget build(BuildContext context) {
    final videoFeed = ref.watch(videoFeedProvider);
    final controller = ref.watch(videoFeedControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Short Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshVideos,
        child: videoFeed.when(
          data: (videos) {
            final filteredVideos = _isOffline
                ? videos.where((v) => _cachedIds.contains(v.id)).toList()
                : videos;
            
            if (_isOffline && filteredVideos.isEmpty) {
              return const Center(
                child: Text(
                  'Connect to the internet to load more videos',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            if (filteredVideos.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No videos yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload your first video!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: filteredVideos.length,
              onPageChanged: (index) => controller.onPageChanged(index, filteredVideos),
              itemBuilder: (context, index) {
                final video = filteredVideos[index];
                final isCached = _cachedIds.contains(video.id);
                
                return Stack(
                  children: [
                    // Video Player
                    isCached || !_isOffline
                        ? VideoPlayerWidget(videoId: video.id, videoUrl: video.url)
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: Text(
                                'Connect to the internet to play this video',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                    
                    // Video Info Overlay
                    Positioned(
                      left: 16,
                      bottom: 32,
                      right: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Username
                          Text(
                            '@${video.username}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Caption
                          if (video.caption.isNotEmpty)
                            Text(
                              video.caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          const SizedBox(height: 8),
                          
                          // Music info
                          Row(
                            children: [
                              const Icon(
                                Icons.music_note,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                video.music,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          
                          // Hashtags
                          if (video.hashtags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              children: video.hashtags.take(3).map((hashtag) => 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hashtag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Action Buttons
                    Positioned(
                      right: 16,
                      bottom: 32,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like Button
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  // TODO: Implement like functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Liked!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${video.likes}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Comment Button
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.comment,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  // TODO: Implement comment functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Comment feature coming soon!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${video.comments}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Share Button
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  // TODO: Implement share functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Share feature coming soon!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              Text(
                                '${video.shares}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(videoFeedProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const UploadScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 