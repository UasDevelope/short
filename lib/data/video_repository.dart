import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_model.dart';

class VideoRepository {
  final _videosRef = FirebaseFirestore.instance.collection('videos');

  Future<List<VideoModel>> fetchVideos() async {
    try {
      final snapshot = await _videosRef
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('No videos found in Firestore, returning sample data');
        return _getSampleVideos();
      }
      
      final videos = snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.data(), doc.id))
          .toList();
      
      print('Fetched ${videos.length} videos from Firestore');
      return videos;
    } catch (e) {
      print('Error fetching videos from Firestore: $e');
      // Return sample data if Firestore fails
      return _getSampleVideos();
    }
  }

  // Refresh videos (for pull-to-refresh)
  Future<List<VideoModel>> refreshVideos() async {
    try {
      final snapshot = await _videosRef
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      
      final videos = snapshot.docs
          .map((doc) => VideoModel.fromMap(doc.data(), doc.id))
          .toList();
      
      print('Refreshed ${videos.length} videos from Firestore');
      return videos;
    } catch (e) {
      print('Error refreshing videos from Firestore: $e');
      return _getSampleVideos();
    }
  }

  Future<void> likeVideo(String videoId) async {
    try {
      await _videosRef.doc(videoId).update({
        'likes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error liking video: $e');
    }
  }

  Future<void> uploadVideo(VideoModel video) async {
    try {
      await _videosRef.add({
        ...video.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading video: $e');
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<void> _createSampleVideos() async {
    final sampleVideos = _getSampleVideos();
    
    for (final video in sampleVideos) {
      try {
        await _videosRef.add({
          ...video.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error creating sample video: $e');
      }
    }
  }

  List<VideoModel> _getSampleVideos() {
    return [
      VideoModel(
        id: '1',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        username: 'user1',
        caption: 'Amazing sunset view! 🌅',
        music: 'Chill Vibes',
        likes: 1234,
        comments: 89,
        shares: 45,
        hashtags: ['#nature', '#beautiful', '#sunset'],
      ),
      VideoModel(
        id: '2',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        username: 'user2',
        caption: 'Dance moves 💃',
        music: 'Trending Beat',
        likes: 567,
        comments: 34,
        shares: 12,
        hashtags: ['#dance', '#fun', '#trending'],
      ),
      VideoModel(
        id: '3',
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        username: 'user3',
        caption: 'Cooking tutorial 👨‍🍳',
        music: 'Upbeat',
        likes: 890,
        comments: 67,
        shares: 23,
        hashtags: ['#cooking', '#food', '#tutorial'],
      ),
    ];
  }
} 