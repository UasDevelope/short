import 'dart:io';
import 'advanced_cache_service.dart';

class AdvancedCacheTest {
  static Future<void> runTests() async {
    print('🧪 Running Advanced Cache Tests...\n');
    
    final cacheService = AdvancedCacheService();
    
    // Test 1: Basic functionality
    print('1. Testing basic cache functionality...');
    final testVideoId = 'test_video_${DateTime.now().millisecondsSinceEpoch}';
    final testUrl = 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
    
    try {
      // Test caching
      final cachedFile = await cacheService.cacheVideo(
        testVideoId,
        testUrl,
        isImportant: true,
      );
      
      if (cachedFile != null && await cachedFile.exists()) {
        print('✅ Video cached successfully');
      } else {
        print('❌ Video caching failed');
      }
      
      // Test cache status
      final isCached = await cacheService.isCached(testVideoId);
      print(isCached ? '✅ Cache status check works' : '❌ Cache status check failed');
      
      // Test settings
      final settings = await cacheService.getCacheSettings();
      print('✅ Settings loaded: ${settings.length} settings');
      
      // Test stats
      final stats = await cacheService.getCacheStats();
      print('✅ Stats loaded: ${stats['totalVideos']} videos, ${stats['healthStatus']} health');
      
      // Test priority queue
      cacheService.addToPreloadQueue(
        'test_priority_1',
        testUrl,
        scrollVelocity: 0.1,
        isEngaging: true,
        userEngagement: 50,
      );
      print('✅ Priority queue works');
      
      // Test chunk caching
      final isChunkCached = await cacheService.isChunkCached(testVideoId, 0);
      print('✅ Chunk caching system works');
      
      // Test adaptive caching
      final adaptiveFile = await cacheService.cacheVideoAdaptive(
        'test_adaptive_${DateTime.now().millisecondsSinceEpoch}',
        testUrl,
        isImportant: false,
      );
      print(adaptiveFile != null ? '✅ Adaptive caching works' : '❌ Adaptive caching failed');
      
      // Test cleanup
      await cacheService.clearCache(keepImportant: true);
      print('✅ Cache cleanup works');
      
    } catch (e) {
      print('❌ Test failed with error: $e');
    }
    
    print('\n🎉 Advanced Cache Tests Completed!');
  }
  
  static Future<void> testPerformance() async {
    print('\n🚀 Testing Performance...');
    
    final cacheService = AdvancedCacheService();
    final stopwatch = Stopwatch();
    
    // Test settings load time
    stopwatch.start();
    await cacheService.getCacheSettings();
    stopwatch.stop();
    print('Settings load time: ${stopwatch.elapsedMilliseconds}ms');
    
    // Test stats load time
    stopwatch.reset();
    stopwatch.start();
    await cacheService.getCacheStats();
    stopwatch.stop();
    print('Stats load time: ${stopwatch.elapsedMilliseconds}ms');
    
    // Test preload queue processing
    stopwatch.reset();
    stopwatch.start();
    await cacheService.processPreloadQueue();
    stopwatch.stop();
    print('Preload queue processing time: ${stopwatch.elapsedMilliseconds}ms');
    
    print('✅ Performance tests completed');
  }
}

// Usage example:
// void main() async {
//   await AdvancedCacheTest.runTests();
//   await AdvancedCacheTest.testPerformance();
// } 