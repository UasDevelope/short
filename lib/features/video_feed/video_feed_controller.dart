import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/video_model.dart';
import '../../services/video_cache_service.dart';

final videoCacheServiceProvider = Provider((ref) => VideoCacheService());

final videoFeedControllerProvider = StateNotifierProvider<VideoFeedController, int>((ref) {
  return VideoFeedController(ref);
});

class VideoFeedController extends StateNotifier<int> {
  final Ref ref;
  Timer? _watchTimer;
  String? _currentVideoId;

  VideoFeedController(this.ref) : super(0);

  void onPageChanged(int index, List<VideoModel> videos) async {
    state = index;
    final cacheService = ref.read(videoCacheServiceProvider);
    final video = videos[index];
    _currentVideoId = video.id;
    _watchTimer?.cancel();
    _watchTimer = Timer(const Duration(seconds: 3), () async {
      await cacheService.updateMeta(video.id); // Mark as recently accessed
    });

    // Preload next 2 and previous 1
    for (var offset in [-1, 1, 2]) {
      final idx = index + offset;
      if (idx >= 0 && idx < videos.length) {
        final v = videos[idx];
        if (!await cacheService.isCached(v.id)) {
          cacheService.cacheVideo(v.id, v.url);
        }
      }
    }
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
  }
} 