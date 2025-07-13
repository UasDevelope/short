import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/video_repository.dart';
import '../../data/video_model.dart';

final isFeedActiveProvider = StateProvider<bool>((ref) => true);

final videoRepositoryProvider = Provider((ref) => VideoRepository());

final videoFeedProvider = FutureProvider<List<VideoModel>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return repo.fetchVideos();
});

// Provider for refresh functionality
final videoFeedRefreshProvider = FutureProvider.family<List<VideoModel>, void>((ref, _) async {
  final repo = ref.watch(videoRepositoryProvider);
  return repo.refreshVideos();
}); 