import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'advanced_cache_service.dart';

class EnhancedCacheService {
  static const historyBoxName = 'videoHistory';
  static const qualityBoxName = 'videoQualitySettings';
  static const downloadBoxName = 'manualDownloads';
  static const settingsBoxName = 'advancedCacheSettings';

  // Video quality options
  static const Map<String, String> qualityLevels = {
    'low': '480p',
    'medium': '720p',
    'high': '1080p',
    'auto': 'auto',
  };

  // Scroll prediction variables
  double _lastScrollTime = 0;
  double _scrollVelocity = 0;
  bool _isScrolling = false;
  int _preloadCount = 2; // Default preload count

  // Initialize services
  final AdvancedCacheService _advancedCacheService = AdvancedCacheService();
  final Dio _dio = Dio();
  final Battery _battery = Battery();

  // Get video history
  Future<List<Map<String, dynamic>>> getVideoHistory() async {
    final box = await Hive.openBox(historyBoxName);
    final history = <Map<String, dynamic>>[];

    for (final entry in box.toMap().entries) {
      history.add({'videoId': entry.key, ...entry.value});
    }

    // Sort by last watched (newest first)
    history.sort(
      (a, b) => (b['lastWatched'] ?? 0).compareTo(a['lastWatched'] ?? 0),
    );
    return history;
  }

  // Add video to history
  Future<void> addToHistory(
    String videoId, {
    double completionPercent = 0.0,
    int watchTime = 0,
  }) async {
    final box = await Hive.openBox(historyBoxName);
    final now = DateTime.now().millisecondsSinceEpoch;

    box.put(videoId, {
      'lastWatched': now,
      'completionPercent': completionPercent,
      'watchTime': watchTime,
      'viewCount': (box.get(videoId)?['viewCount'] ?? 0) + 1,
    });
  }

  // Check if video was recently watched
  Future<bool> isRecentlyWatched(String videoId, {int hours = 24}) async {
    final box = await Hive.openBox(historyBoxName);
    final videoData = box.get(videoId);
    if (videoData == null) return false;

    final lastWatched = videoData['lastWatched'] ?? 0;
    final hoursSinceWatched =
        (DateTime.now().millisecondsSinceEpoch - lastWatched) /
        (1000 * 60 * 60);

    return hoursSinceWatched < hours;
  }

  // Get user's quality preference
  Future<String> getUserQualityPreference() async {
    final box = await Hive.openBox(qualityBoxName);
    return box.get('quality', defaultValue: 'auto');
  }

  // Set user's quality preference
  Future<void> setUserQualityPreference(String quality) async {
    final box = await Hive.openBox(qualityBoxName);
    box.put('quality', quality);
  }

  // Get adaptive quality URL based on user preference and network
  Future<String> getAdaptiveQualityUrl(String originalUrl) async {
    final quality = await getUserQualityPreference();
    final connectivity = await Connectivity().checkConnectivity();

    if (quality == 'auto') {
      // Auto quality based on network
      if (connectivity == ConnectivityResult.mobile) {
        return _getLowerQualityUrl(originalUrl);
      } else {
        return originalUrl; // Use original for Wi-Fi
      }
    } else {
      // User-specified quality
      return _getQualityUrl(originalUrl, quality);
    }
  }

  // Get lower quality URL (placeholder implementation)
  String _getLowerQualityUrl(String originalUrl) {
    // In real implementation, you'd have different quality URLs
    // For now, return original URL
    return originalUrl;
  }

  // Get URL for specific quality
  String _getQualityUrl(String originalUrl, String quality) {
    // In real implementation, you'd have different quality URLs
    // For now, return original URL
    return originalUrl;
  }

  // Update scroll velocity for better preloading
  void updateScrollVelocity(double velocity) {
    _scrollVelocity = velocity;
    _lastScrollTime = DateTime.now().millisecondsSinceEpoch / 1000;
    _isScrolling = velocity > 0.1;

    // Adjust preload count based on scroll velocity
    if (velocity > 2.0) {
      _preloadCount = 0; // Skip preloading for fast scroll
    } else if (velocity > 1.0) {
      _preloadCount = 1; // Minimal preloading
    } else if (velocity < 0.5) {
      _preloadCount = 3; // More preloading for slow scroll
    } else {
      _preloadCount = 2; // Default
    }
  }

  // Enhanced preload queue with scroll prediction
  void addToPreloadQueue(
    String videoId,
    String url, {
    double scrollVelocity = 0.0,
    bool isEngaging = false,
    int userEngagement = 0,
  }) {
    // Skip if scrolling too fast
    if (_scrollVelocity > 2.0) return;

    // Skip if recently watched
    isRecentlyWatched(videoId).then((recentlyWatched) {
      if (recentlyWatched) return;

      final priority = _calculatePriority(
        scrollVelocity,
        isEngaging,
        userEngagement,
      );

      // Use the advanced cache service for preload queue
      _advancedCacheService.addToPreloadQueue(
        videoId,
        url,
        scrollVelocity: scrollVelocity,
        isEngaging: isEngaging,
        userEngagement: userEngagement,
      );
    });
  }

  // Calculate preload priority
  double _calculatePriority(
    double scrollVelocity,
    bool isEngaging,
    int userEngagement,
  ) {
    double priority = 0.0;

    // Lower scroll velocity = higher priority (user is watching)
    priority += max(0, 1 - scrollVelocity) * 0.4;

    // Engagement bonus
    if (isEngaging) priority += 0.3;

    // User engagement history
    priority += min(userEngagement / 100.0, 1.0) * 0.3;

    return priority;
  }

  // Enhanced preload processing with chunked optimization
  Future<void> processPreloadQueue() async {
    if (!await shouldPreload()) return;

    // Use the advanced cache service for processing
    await _advancedCacheService.processPreloadQueue();
  }

  // Preload only first chunk for faster loading
  Future<bool> _preloadFirstChunkOnly(String videoId, String url) async {
    try {
      final chunkDir = await _advancedCacheService.getChunkDir(videoId);
      final firstChunkPath = '${chunkDir.path}/chunk_0.mp4';

      // Check if already cached
      final chunkFile = File(firstChunkPath);
      if (await chunkFile.exists()) return true;

      // Download first chunk only
      await _dio.download(url, firstChunkPath);
      await _updateChunkMetadata(videoId, 0, true);

      return true;
    } catch (e) {
      print('Error preloading first chunk: $e');
      return false;
    }
  }

  // Update chunk metadata
  Future<void> _updateChunkMetadata(
    String videoId,
    int chunkIndex,
    bool cached,
  ) async {
    final box = await Hive.openBox('advancedVideoCacheMeta');
    final existing = box.get(videoId) ?? {};
    final chunks = List<bool>.from(existing['chunks'] ?? []);

    while (chunks.length <= chunkIndex) {
      chunks.add(false);
    }
    chunks[chunkIndex] = cached;

    box.put(videoId, {
      ...existing,
      'chunks': chunks,
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Manual download with pinning
  Future<bool> manualDownload(String videoId, String url) async {
    try {
      // Mark as manually downloaded (pinned)
      final box = await Hive.openBox(downloadBoxName);
      box.put(videoId, {
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'pinned': true,
      });

      // Download full video using advanced cache service
      final cachedFile = await _advancedCacheService.cacheVideo(
        videoId,
        url,
        isImportant: true, // Mark as important to prevent auto-deletion
      );

      return cachedFile != null;
    } catch (e) {
      print('Error manual download: $e');
      return false;
    }
  }

  // Check if video is manually downloaded
  Future<bool> isManuallyDownloaded(String videoId) async {
    final box = await Hive.openBox(downloadBoxName);
    return box.get(videoId)?['pinned'] == true;
  }

  // Get manually downloaded videos
  Future<List<String>> getManuallyDownloadedVideos() async {
    final box = await Hive.openBox(downloadBoxName);
    final downloaded = <String>[];

    for (final entry in box.toMap().entries) {
      if (entry.value['pinned'] == true) {
        downloaded.add(entry.key);
      }
    }

    return downloaded;
  }

  // Enhanced cache stats with more details
  Future<Map<String, dynamic>> getEnhancedCacheStats() async {
    final baseStats = await _advancedCacheService.getCacheStats();
    final history = await getVideoHistory();
    final manualDownloads = await getManuallyDownloadedVideos();

    // Get storage info
    final cacheDir = await _advancedCacheService.getCacheDir();
    final tempDir = await _advancedCacheService.getTempDir();

    int cacheSize = 0;
    int tempSize = 0;

    try {
      await for (final file in cacheDir.list(recursive: true)) {
        if (file is File) {
          cacheSize += await file.length();
        }
      }

      await for (final file in tempDir.list(recursive: true)) {
        if (file is File) {
          tempSize += await file.length();
        }
      }
    } catch (e) {
      print('Error calculating storage: $e');
    }

    return {
      ...baseStats,
      'historyCount': history.length,
      'manualDownloadsCount': manualDownloads.length,
      'cacheSizeBytes': cacheSize,
      'tempSizeBytes': tempSize,
      'scrollVelocity': _scrollVelocity,
      'isScrolling': _isScrolling,
      'preloadCount': _preloadCount,
    };
  }

  // Get offline videos (cached + manually downloaded)
  Future<List<String>> getOfflineVideos() async {
    final cachedIds = await _advancedCacheService.getCachedVideoIds();
    final manualDownloads = await getManuallyDownloadedVideos();

    final offlineIds = <String>{};
    offlineIds.addAll(cachedIds);
    offlineIds.addAll(manualDownloads);

    return offlineIds.toList();
  }

  // Battery saver mode
  Future<bool> isBatterySaverEnabled() async {
    final box = await Hive.openBox(settingsBoxName);
    return box.get('batterySaver', defaultValue: false);
  }

  // Set battery saver mode
  Future<void> setBatterySaverMode(bool enabled) async {
    final box = await Hive.openBox(settingsBoxName);
    box.put('batterySaver', enabled);
  }

  // Enhanced shouldPreload with battery saver
  Future<bool> shouldPreload() async {
    final batterySaver = await isBatterySaverEnabled();
    if (batterySaver) return false;

    return await _advancedCacheService.shouldPreload();
  }

  // Get adaptive buffer size based on network and device
  Future<int> getAdaptiveBufferSize() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();

      // Base buffer size
      int bufferSize = 5; // 5 seconds default

      // Adjust based on network
      if (connectivity == ConnectivityResult.mobile) {
        bufferSize = 3; // Smaller buffer for mobile
      } else {
        bufferSize = 8; // Larger buffer for Wi-Fi
      }

      // Only adjust based on battery if the plugin is available
      try {
        final batteryLevel = await _battery.batteryLevel;
        if (batteryLevel < 20) {
          bufferSize = (bufferSize * 0.5)
              .round(); // Reduce buffer on low battery
        }
      } catch (e) {
        print('Battery info unavailable, using default buffer size: $e');
        // Continue with network-adjusted buffer size
      }

      return bufferSize;
    } catch (e) {
      print('Error in getAdaptiveBufferSize: $e');
      return 5; // Default buffer size on error
    }
  }

  // Graceful fallback for failed downloads
  Future<void> handleDownloadFailure(String videoId, String error) async {
    print('Download failed for $videoId: $error');

    // Add to retry queue for later
    // In a real implementation, you'd have a retry mechanism
  }

  // Clear video history
  Future<void> clearVideoHistory() async {
    final box = await Hive.openBox(historyBoxName);
    await box.clear();
  }

  // Remove manual download
  Future<void> removeManualDownload(String videoId) async {
    final box = await Hive.openBox(downloadBoxName);
    await box.delete(videoId);

    // Also delete the cached file using advanced cache service
    // Note: We'll need to implement this in the advanced cache service
    // For now, just remove from manual downloads
  }

  // Get cache settings
  Future<Map<String, dynamic>> getCacheSettings() async {
    return await _advancedCacheService.getCacheSettings();
  }

  // Update cache settings
  Future<void> updateCacheSettings(Map<String, dynamic> settings) async {
    await _advancedCacheService.updateCacheSettings(settings);
  }

  // Clear cache with options
  Future<void> clearCache({
    bool keepImportant = false,
    bool keepHighScore = false,
  }) async {
    await _advancedCacheService.clearCache(
      keepImportant: keepImportant,
      keepHighScore: keepHighScore,
    );
  }

  // Public method to get cached file path for a videoId
  Future<String> getCachedFilePath(String videoId) async {
    return await _advancedCacheService.getCachedFilePath(videoId);
  }
}
