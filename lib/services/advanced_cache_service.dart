import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class AdvancedCacheService {
  static const cacheBoxName = 'advancedVideoCacheMeta';
  static const settingsBoxName = 'advancedCacheSettings';
  static const chunkSize = 5; // 5-second chunks

  final Dio _dio = Dio();
  final Battery _battery = Battery();
  final Random _random = Random();

  // Priority queue for preloading
  final List<CachePriority> _preloadQueue = [];

  // AI-based importance scoring
  double _calculateImportanceScore(Map<String, dynamic> videoData) {
    final watchedTime = videoData['watchedTime'] ?? 0.0;
    final duration = videoData['duration'] ?? 1.0;
    final liked = videoData['liked'] ?? false;
    final shared = videoData['shared'] ?? false;
    final bookmarked = videoData['bookmarked'] ?? false;
    final scrollVelocity = videoData['scrollVelocity'] ?? 0.0;

    double score = 0.0;

    // Watch completion ratio (0-1)
    score += (watchedTime / duration) * 0.4;

    // Engagement factors
    if (liked) score += 0.2;
    if (shared) score += 0.2;
    if (bookmarked) score += 0.3;

    // Scroll velocity (faster = less important)
    score += max(0, 1 - scrollVelocity) * 0.1;

    return score;
  }

  // Get cache directory with chunked structure
  Future<Directory> getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/advanced_video_cache');
    if (!await cacheDir.exists()) await cacheDir.create();
    return cacheDir;
  }

  // Get chunk directory for segmented caching
  Future<Directory> getChunkDir(String videoId) async {
    final cacheDir = await getCacheDir();
    final chunkDir = Directory('${cacheDir.path}/$videoId/chunks');
    if (!await chunkDir.exists()) await chunkDir.create(recursive: true);
    return chunkDir;
  }

  // Get temp directory with auto-cleanup
  Future<Directory> getTempDir() async {
    final dir = await getTemporaryDirectory();
    final tempDir = Directory('${dir.path}/advanced_video_cache_temp');
    if (!await tempDir.exists()) await tempDir.create();

    // Auto-cleanup old temp files
    await _cleanupTempFiles();

    return tempDir;
  }

  // Cleanup temp files older than 24 hours
  Future<void> _cleanupTempFiles() async {
    final tempDir = await getTempDir();
    final now = DateTime.now();

    try {
      await for (final file in tempDir.list()) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age.inHours > 24) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning temp files: $e');
    }
  }

  // Context-aware preloading with priority queue
  Future<bool> shouldPreload() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final settings = await getCacheSettings();

      // Check user settings
      if (connectivity == ConnectivityResult.mobile &&
          !settings['preloadOnMobile']) {
        return false;
      }

      // Only check battery if the plugin is available
      try {
        final batteryLevel = await _battery.batteryLevel;
        final isCharging = await _battery.isInBatterySaveMode;
        
        if (batteryLevel < 20 && !isCharging && !settings['preloadOnLowBattery']) {
          return false;
        }
      } catch (e) {
        print('Battery info unavailable, continuing without battery checks: $e');
        // Continue without battery checks
      }

      return true;
    } catch (e) {
      print('Error in shouldPreload: $e');
      return true; // Default to allowing preload on error
    }
  }

  // Add video to preload queue with priority
  void addToPreloadQueue(
    String videoId,
    String url, {
    double scrollVelocity = 0.0,
    bool isEngaging = false,
    int userEngagement = 0,
  }) {
    final priority = _calculatePriority(
      scrollVelocity,
      isEngaging,
      userEngagement,
    );
    _preloadQueue.add(
      CachePriority(
        videoId: videoId,
        url: url,
        priority: priority,
        timestamp: DateTime.now(),
      ),
    );

    // Sort queue by priority
    _preloadQueue.sort((a, b) => b.priority.compareTo(a.priority));

    // Keep only top 5 videos in queue
    if (_preloadQueue.length > 5) {
      _preloadQueue.removeRange(5, _preloadQueue.length);
    }
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

  // Process preload queue
  Future<void> processPreloadQueue() async {
    if (!await shouldPreload()) return;

    for (final item in _preloadQueue.take(2)) {
      await _preloadVideoChunks(item.videoId, item.url);
    }
  }

  // Preload video in chunks
  Future<bool> _preloadVideoChunks(String videoId, String url) async {
    try {
      final chunkDir = await getChunkDir(videoId);

      // Download first chunk (0-5 seconds)
      final firstChunkPath = '${chunkDir.path}/chunk_0.mp4';
      await _dio.download(url, firstChunkPath);

      // Update metadata
      await _updateChunkMetadata(videoId, 0, true);

      return true;
    } catch (e) {
      print('Error preloading video chunks: $e');
      return false;
    }
  }

  // Cache video with adaptive quality
  Future<File?> cacheVideoAdaptive(
    String videoId,
    String url, {
    Function(double)? onProgress,
    bool isImportant = false,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final settings = await getCacheSettings();

    // Adaptive quality based on network
    String adaptiveUrl = url;
    if (connectivity == ConnectivityResult.mobile) {
      // Use lower quality for mobile
      adaptiveUrl = _getLowerQualityUrl(url);
    }

    return await cacheVideo(
      videoId,
      adaptiveUrl,
      onProgress: onProgress,
      isImportant: isImportant,
    );
  }

  // Get lower quality URL (placeholder implementation)
  String _getLowerQualityUrl(String originalUrl) {
    // In real implementation, you'd have different quality URLs
    // For now, return original URL
    return originalUrl;
  }

  // Cache video with progress and chunking
  Future<File?> cacheVideo(
    String videoId,
    String url, {
    Function(double)? onProgress,
    bool isImportant = false,
  }) async {
    final filePath = await getCachedFilePath(videoId);
    final file = File(filePath);

    if (await isCached(videoId)) {
      await updateMeta(videoId, important: isImportant);
      return file;
    }

    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total != -1) {
            onProgress!(received / total);
          }
        },
      );

      await updateMeta(videoId, important: isImportant);
      await _cleanupIfNeeded();
      return file;
    } catch (e) {
      print('Error caching video: $e');
      return null;
    }
  }

  // Get cached file path
  Future<String> getCachedFilePath(String videoId) async {
    final dir = await getCacheDir();
    return '${dir.path}/$videoId.mp4';
  }

  // Check if video is cached
  Future<bool> isCached(String videoId) async {
    final file = File(await getCachedFilePath(videoId));
    return file.existsSync();
  }

  // Check if video chunk is cached
  Future<bool> isChunkCached(String videoId, int chunkIndex) async {
    final chunkDir = await getChunkDir(videoId);
    final chunkFile = File('${chunkDir.path}/chunk_$chunkIndex.mp4');
    return chunkFile.existsSync();
  }

  // Update chunk metadata
  Future<void> _updateChunkMetadata(
    String videoId,
    int chunkIndex,
    bool cached,
  ) async {
    final box = await Hive.openBox(cacheBoxName);
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

  // Update cache metadata with AI scoring
  Future<void> updateMeta(String videoId, {bool important = false}) async {
    final box = await Hive.openBox(cacheBoxName);
    final existing = box.get(videoId) ?? {};

    // Calculate AI importance score
    final importanceScore = _calculateImportanceScore(existing);

    box.put(videoId, {
      ...existing,
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
      'important': important,
      'importanceScore': importanceScore,
      'size': await _getFileSize(videoId),
    });
  }

  // Get file size
  Future<int> _getFileSize(String videoId) async {
    try {
      final file = File(await getCachedFilePath(videoId));
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
    return 0;
  }

  // Smart cleanup with AI scoring
  Future<void> _cleanupIfNeeded() async {
    final box = await Hive.openBox(cacheBoxName);
    final settings = await getCacheSettings();
    final maxCache = settings['maxCacheSize'] ?? 50;

    if (box.length > maxCache) {
      final videos = box.toMap().entries.toList();

      // Sort by AI importance score and last accessed
      videos.sort((a, b) {
        final scoreA = a.value['importanceScore'] ?? 0.0;
        final scoreB = b.value['importanceScore'] ?? 0.0;

        if ((scoreA - scoreB).abs() > 0.1) {
          return scoreB.compareTo(scoreA); // Higher score first
        }

        // If scores are similar, use last accessed time
        final timeA = a.value['lastAccessed'] ?? 0;
        final timeB = b.value['lastAccessed'] ?? 0;
        return timeA.compareTo(timeB);
      });

      // Remove least important videos
      final toDelete = videos.take(box.length - (maxCache as int));
      for (final entry in toDelete) {
        await _deleteVideo(entry.key);
        await box.delete(entry.key);
      }
    }
  }

  // Delete video and chunks
  Future<void> _deleteVideo(String videoId) async {
    try {
      final file = File(await getCachedFilePath(videoId));
      if (await file.exists()) await file.delete();

      final chunkDir = await getChunkDir(videoId);
      if (await chunkDir.exists()) {
        await chunkDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error deleting video: $e');
    }
  }

  // Get cache statistics with health status
  Future<Map<String, dynamic>> getCacheStats() async {
    final box = await Hive.openBox(cacheBoxName);
    final settings = await getCacheSettings();
    final videos = box.toMap();

    int totalSize = 0;
    int importantCount = 0;
    double avgImportanceScore = 0.0;

    for (final entry in videos.entries) {
      totalSize += (entry.value['size'] ?? 0) as int;
      if (entry.value['important'] == true) importantCount++;
      avgImportanceScore += (entry.value['importanceScore'] ?? 0.0) as double;
    }

    final maxCache = settings['maxCacheSize'] ?? 50;
    final usagePercent = (videos.length / maxCache) * 100;

    return {
      'totalVideos': videos.length,
      'importantVideos': importantCount,
      'totalSize': totalSize,
      'maxCache': maxCache,
      'usagePercent': usagePercent,
      'avgImportanceScore': videos.isNotEmpty
          ? avgImportanceScore / videos.length
          : 0.0,
      'healthStatus': _getHealthStatus(usagePercent),
    };
  }

  // Get cache health status
  String _getHealthStatus(double usagePercent) {
    if (usagePercent < 50) return 'Excellent';
    if (usagePercent < 75) return 'Good';
    if (usagePercent < 90) return 'Warning';
    return 'Critical';
  }

  // Get cache settings
  Future<Map<String, dynamic>> getCacheSettings() async {
    final box = await Hive.openBox(settingsBoxName);
    return {
      'maxCacheSize': box.get('maxCacheSize', defaultValue: 50),
      'preloadOnWifi': box.get('preloadOnWifi', defaultValue: true),
      'preloadOnCharging': box.get('preloadOnCharging', defaultValue: true),
      'preloadOnLowBattery': box.get(
        'preloadOnLowBattery',
        defaultValue: false,
      ),
      'preloadOnMobile': box.get('preloadOnMobile', defaultValue: false),
      'adaptiveQuality': box.get('adaptiveQuality', defaultValue: true),
      'autoCleanup': box.get('autoCleanup', defaultValue: true),
    };
  }



  // Update cache settings
  Future<void> updateCacheSettings(Map<String, dynamic> settings) async {
    final box = await Hive.openBox(settingsBoxName);
    for (final entry in settings.entries) {
      box.put(entry.key, entry.value);
    }
  }

  // Clear cache with options
  Future<void> clearCache({
    bool keepImportant = false,
    bool keepHighScore = false,
  }) async {
    final box = await Hive.openBox(cacheBoxName);
    final videos = box.toMap();

    for (final entry in videos.entries) {
      final shouldKeep =
          keepImportant && entry.value['important'] == true ||
          keepHighScore && (entry.value['importanceScore'] ?? 0.0) > 0.7;

      if (!shouldKeep) {
        await _deleteVideo(entry.key);
        await box.delete(entry.key);
      }
    }
  }

  // Get cached video IDs
  Future<List<String>> getCachedVideoIds() async {
    final box = await Hive.openBox(cacheBoxName);
    return box.keys.cast<String>().toList();
  }

  // Mark video as important
  Future<void> markImportant(String videoId, bool important) async {
    final box = await Hive.openBox(cacheBoxName);
    final meta = box.get(videoId);
    if (meta != null) {
      box.put(videoId, {...meta, 'important': important});
    }
  }
}

// Priority queue item for preloading
class CachePriority {
  final String videoId;
  final String url;
  final double priority;
  final DateTime timestamp;

  CachePriority({
    required this.videoId,
    required this.url,
    required this.priority,
    required this.timestamp,
  });
}
