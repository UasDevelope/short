import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class VideoCacheService {
  static const maxCacheCount = 50;
  static const cacheBoxName = 'videoCacheMeta';

  final Dio _dio = Dio();

  Future<Directory> getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/video_cache');
    if (!await cacheDir.exists()) await cacheDir.create();
    return cacheDir;
  }

  Future<String> getCachedFilePath(String videoId) async {
    final dir = await getCacheDir();
    return '${dir.path}/$videoId.mp4';
  }

  Future<bool> isCached(String videoId) async {
    final file = File(await getCachedFilePath(videoId));
    return file.existsSync();
  }

  Future<File?> cacheVideo(String videoId, String url) async {
    final filePath = await getCachedFilePath(videoId);
    final file = File(filePath);
    if (await isCached(videoId)) {
      await updateMeta(videoId);
      return file;
    }
    try {
      await _dio.download(url, filePath);
      await updateMeta(videoId);
      await _cleanupIfNeeded();
      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateMeta(String videoId, {bool important = false}) async {
    final box = await Hive.openBox(cacheBoxName);
    box.put(videoId, {
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
      'important': important,
    });
  }

  Future<void> _cleanupIfNeeded() async {
    final box = await Hive.openBox(cacheBoxName);
    if (box.length > maxCacheCount) {
      final sorted = box.toMap().entries.toList()
        ..sort((a, b) => ((a.value['important'] == true ? 1 : 0) - (b.value['important'] == true ? 1 : 0)) != 0
            ? (b.value['important'] == true ? 1 : 0) - (a.value['important'] == true ? 1 : 0)
            : (a.value['lastAccessed'] as int).compareTo(b.value['lastAccessed'] as int));
      final toDelete = sorted.where((e) => e.value['important'] != true).take(box.length - maxCacheCount);
      for (final entry in toDelete) {
        final file = File(await getCachedFilePath(entry.key));
        if (await file.exists()) await file.delete();
        await box.delete(entry.key);
      }
    }
  }

  Future<List<String>> getCachedVideoIds() async {
    final box = await Hive.openBox(cacheBoxName);
    return box.keys.cast<String>().toList();
  }

  Future<void> markImportant(String videoId, bool important) async {
    final box = await Hive.openBox(cacheBoxName);
    final meta = box.get(videoId);
    if (meta != null) {
      box.put(videoId, {
        ...meta,
        'important': important,
      });
    }
  }
} 