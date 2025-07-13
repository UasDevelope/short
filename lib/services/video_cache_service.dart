import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class VideoCacheService {
  static const cacheBoxName = 'videoCacheMeta';
  static const settingsBoxName = 'cacheSettings';

  final Dio _dio = Dio();
  final Battery _battery = Battery();

  // Dynamic cache size based on device storage
  int get _maxCacheCount {
    // This would be calculated based on available storage
    // For now, using a reasonable default
    return 50;
  }

  // Get cache directory
  Future<Directory> getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/video_cache');
    if (!await cacheDir.exists()) await cacheDir.create();
    return cacheDir;
  }

  // Get temporary directory for partial downloads
  Future<Directory> getTempDir() async {
    final dir = await getTemporaryDirectory();
    final tempDir = Directory('${dir.path}/video_cache_temp');
    if (!await tempDir.exists()) await tempDir.create();
    return tempDir;
  }

  // Check if should preload based on context
  Future<bool> shouldPreload() async {
    final connectivity = await Connectivity().checkConnectivity();
    final batteryLevel = await _battery.batteryLevel;
    final isCharging = await _battery.isInBatterySaveMode;

    // Don't preload on mobile data or low battery
    if (connectivity == ConnectivityResult.mobile) return false;
    if (batteryLevel < 20 && !isCharging) return false;

    return true;
  }

  // Get cached file path
  Future<String> getCachedFilePath(String videoId) async {
    final dir = await getCacheDir();
    return '${dir.path}/$videoId.mp4';
  }

  // Get partial cache file path
  Future<String> getPartialCacheFilePath(String videoId) async {
    final dir = await getTempDir();
    return '${dir.path}/${videoId}_partial.mp4';
  }

  // Check if video is cached
  Future<bool> isCached(String videoId) async {
    final file = File(await getCachedFilePath(videoId));
    return file.existsSync();
  }

  // Check if video is partially cached
  Future<bool> isPartiallyCached(String videoId) async {
    final file = File(await getPartialCacheFilePath(videoId));
    return file.existsSync();
  }

  // Cache video with progress callback
  Future<File?> cacheVideo(
    String videoId,
    String url, {
    Function(double)? onProgress,
    bool isPartial = false,
    bool isImportant = false,
  }) async {
    final filePath = isPartial
        ? await getPartialCacheFilePath(videoId)
        : await getCachedFilePath(videoId);
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

  // Partial preload (first 5 seconds)
  Future<bool> preloadPartial(String videoId, String url) async {
    if (!await shouldPreload()) return false;

    try {
      // For partial preload, we'd need to implement range requests
      // This is a simplified version
      final partialFile = await cacheVideo(videoId, url, isPartial: true);
      return partialFile != null;
    } catch (e) {
      print('Error preloading partial video: $e');
      return false;
    }
  }

  // Update cache metadata
  Future<void> updateMeta(String videoId, {bool important = false}) async {
    final box = await Hive.openBox(cacheBoxName);
    box.put(videoId, {
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
      'important': important,
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

  // Cleanup cache if needed
  Future<void> _cleanupIfNeeded() async {
    final box = await Hive.openBox(cacheBoxName);
    if (box.length > _maxCacheCount) {
      final sorted = box.toMap().entries.toList()
        ..sort(
          (a, b) =>
              ((a.value['important'] == true ? 1 : 0) -
                      (b.value['important'] == true ? 1 : 0)) !=
                  0
              ? (b.value['important'] == true ? 1 : 0) -
                    (a.value['important'] == true ? 1 : 0)
              : (a.value['lastAccessed'] as int).compareTo(
                  b.value['lastAccessed'] as int,
                ),
        );

      final toDelete = sorted
          .where((e) => e.value['important'] != true)
          .take(box.length - _maxCacheCount);

      for (final entry in toDelete) {
        await _deleteVideo(entry.key);
        await box.delete(entry.key);
      }
    }
  }

  // Delete video from cache
  Future<void> _deleteVideo(String videoId) async {
    try {
      final file = File(await getCachedFilePath(videoId));
      if (await file.exists()) await file.delete();

      final partialFile = File(await getPartialCacheFilePath(videoId));
      if (await partialFile.exists()) await partialFile.delete();
    } catch (e) {
      print('Error deleting video: $e');
    }
  }

  // Get cached video IDs
  Future<List<String>> getCachedVideoIds() async {
    final box = await Hive.openBox(cacheBoxName);
    return box.keys.cast<String>().toList();
  }

  // Mark video as important (pinned)
  Future<void> markImportant(String videoId, bool important) async {
    final box = await Hive.openBox(cacheBoxName);
    final meta = box.get(videoId);
    if (meta != null) {
      box.put(videoId, {...meta, 'important': important});
    }
  }

  // Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final box = await Hive.openBox(cacheBoxName);
    final videos = box.toMap();

    int totalSize = 0;
    int importantCount = 0;

    for (final entry in videos.entries) {
      totalSize += (entry.value['size'] ?? 0) as int;
      if (entry.value['important'] == true) importantCount++;
    }

    return {
      'totalVideos': videos.length,
      'importantVideos': importantCount,
      'totalSize': totalSize,
      'maxCache': _maxCacheCount,
    };
  }

  // Clear cache
  Future<void> clearCache({bool keepImportant = false}) async {
    final box = await Hive.openBox(cacheBoxName);
    final videos = box.toMap();

    for (final entry in videos.entries) {
      if (!keepImportant || entry.value['important'] != true) {
        await _deleteVideo(entry.key);
        await box.delete(entry.key);
      }
    }
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
    };
  }

  // Update cache settings
  Future<void> updateCacheSettings(Map<String, dynamic> settings) async {
    final box = await Hive.openBox(settingsBoxName);
    for (final entry in settings.entries) {
      box.put(entry.key, entry.value);
    }
  }
}
