import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/video_model.dart';
import 'video_feed_provider.dart';
import 'video_feed_controller.dart';
import '../player/video_player_widget.dart';
import '../../services/video_cache_service.dart';
import '../../services/advanced_cache_service.dart';
import '../../services/enhanced_cache_service.dart';
import '../upload/upload_screen.dart';
import '../settings/cache_settings_screen.dart';
import '../settings/advanced_cache_settings_screen.dart';
import '../settings/enhanced_cache_settings_screen.dart';
import '../offline/offline_video_gallery_screen.dart';
import '../../services/auth_service.dart';
import 'package:flutter/widgets.dart';

class VideoFeedScreen extends ConsumerStatefulWidget {
  const VideoFeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen>
    with WidgetsBindingObserver, RouteAware {
  bool _isOffline = false;
  List<String> _cachedIds = [];
  final AdvancedCacheService _advancedCacheService = AdvancedCacheService();
  final EnhancedCacheService _enhancedCacheService = EnhancedCacheService();
  Map<String, dynamic> _cacheStats = {};
  int _currentPage = 0;
  DateTime _lastPreload = DateTime.now();
  bool _isActive = true;
  RouteObserver<ModalRoute<void>>? _routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _loadCachedIds();
    _loadCacheStats();
  }

  void _setFeedActive(bool active) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(isFeedActiveProvider.notifier).state = active;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver = ModalRoute.of(context)?.navigator?.widget.observers
        .whereType<RouteObserver<ModalRoute<void>>>()
        .firstOrNull;
    _routeObserver?.subscribe(this, ModalRoute.of(context)!);
    _setFeedActive(true);
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _setFeedActive(false);
    super.dispose();
  }

  @override
  void didPushNext() {
    // Navigated away from this screen
    setState(() {
      _isActive = false;
    });
    _setFeedActive(false);
  }

  @override
  void didPopNext() {
    // Returned to this screen
    setState(() {
      _isActive = true;
    });
    _setFeedActive(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      setState(() {
        _isActive = false;
      });
      _setFeedActive(false);
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        _isActive = true;
      });
      _setFeedActive(true);
    }
  }

  @override
  void deactivate() {
    setState(() {
      _isActive = false;
    });
    super.deactivate();
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

  Future<void> _loadCacheStats() async {
    final stats = await _enhancedCacheService.getEnhancedCacheStats();
    setState(() {
      _cacheStats = stats;
    });
  }

  Color _getHealthColor(String status) {
    switch (status) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Warning':
        return Colors.orange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _refreshVideos() async {
    // Refresh the video feed
    ref.invalidate(videoFeedProvider);
    await _loadCachedIds();
    await _loadCacheStats();
  }

  @override
  Widget build(BuildContext context) {
    final videoFeed = ref.watch(videoFeedProvider);
    final controller = ref.watch(videoFeedControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Short Video'),
        actions: [
          // Cache Health Indicator
          if (_cacheStats.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getHealthColor(_cacheStats['healthStatus'] ?? 'Good'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.health_and_safety, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${(_cacheStats['usagePercent'] ?? 0).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CacheSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdvancedCacheSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_applications),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EnhancedCacheSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OfflineVideoGalleryScreen(),
                ),
              );
            },
          ),
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
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                controller.onPageChanged(index, filteredVideos);

                // Add video to history
                final currentVideo = filteredVideos[index];
                _enhancedCacheService.addToHistory(
                  currentVideo.id,
                  completionPercent:
                      0.5, // Could be calculated from actual watch time
                  watchTime: 0, // Could be calculated from actual watch time
                );
                // Debounce preloading/AI
                final now = DateTime.now();
                if (now.difference(_lastPreload).inMilliseconds > 500) {
                  _lastPreload = now;
                  // Preload only 2 ahead and 2 behind
                  for (int i = index - 2; i <= index + 2; i++) {
                    if (i >= 0 && i < filteredVideos.length && i != index) {
                      final v = filteredVideos[i];
                      _enhancedCacheService.addToPreloadQueue(
                        v.id,
                        v.url,
                        scrollVelocity: 0.0,
                        isEngaging: v.likes > 100,
                        userEngagement: v.likes + v.comments + v.shares,
                      );
                    }
                  }
                  _enhancedCacheService.processPreloadQueue();
                }
              },
              itemBuilder: (context, index) {
                try {
                  if (index < 0 || index >= filteredVideos.length) {
                    return const Center(
                      child: Text(
                        'No video found for this page',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  final video = filteredVideos[index];
                  final isCached = _cachedIds.contains(video.id);
                  final isCurrent = index == _currentPage && _isActive;

                  return Stack(
                    key: ValueKey(video.id),
                    children: [
                      // Video Player
                      isCached || !_isOffline
                          ? VideoPlayerWidget(
                              videoId: video.id,
                              videoUrl: video.url,
                              play: isCurrent,
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: Text(
                                  'Connect to the internet to play this video',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),

                      // Enhanced Cache Status Indicator with Animation
                      Positioned(
                        top: 16,
                        right: 16,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCached
                                ? Colors.green.withOpacity(0.8)
                                : Colors.orange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCached ? Icons.download_done : Icons.download,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCached ? 'Cached' : 'Preloading',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Manual Download Button
                      Positioned(
                        top: 16,
                        left: 16,
                        child: FutureBuilder<bool>(
                          future: _enhancedCacheService.isManuallyDownloaded(
                            video.id,
                          ),
                          builder: (context, snapshot) {
                            final isManuallyDownloaded = snapshot.data ?? false;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: IconButton(
                                onPressed: () async {
                                  if (isManuallyDownloaded) {
                                    // Remove download
                                    await _enhancedCacheService
                                        .removeManualDownload(video.id);
                                    setState(() {});
                                  } else {
                                    // Add download
                                    final success = await _enhancedCacheService
                                        .manualDownload(video.id, video.url);
                                    if (success) {
                                      debugPrint(
                                        'Manual download succeeded for videoId: ${video.id}',
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Video downloaded for offline use!',
                                            ),
                                          ),
                                        );
                                      }
                                      setState(() {});
                                    } else {
                                      debugPrint(
                                        'Manual download failed for videoId: ${video.id}',
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Download failed. Please try again.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: Icon(
                                  isManuallyDownloaded
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  color: isManuallyDownloaded
                                      ? Colors.purple
                                      : Colors.white,
                                ),
                                tooltip: isManuallyDownloaded
                                    ? 'Unpin from offline'
                                    : 'Pin for offline',
                              ),
                            );
                          },
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
                                children: video.hashtags
                                    .take(3)
                                    .map(
                                      (hashtag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          hashtag,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
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
                                        content: Text(
                                          'Comment feature coming soon!',
                                        ),
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
                                        content: Text(
                                          'Share feature coming soon!',
                                        ),
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
                } catch (e, stack) {
                  return Center(
                    child: Text(
                      'Error loading video: \n\n${e.toString()}',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
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
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const UploadScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
