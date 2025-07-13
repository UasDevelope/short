import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/video_feed/video_feed_screen.dart';
import 'data/video_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Firebase.initializeApp();
  
  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Global error widget override for friendlier error display
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Center(
      child: Text(
        'Oops! Widget error:\n\n${details.exceptionAsString()}',
        style: TextStyle(color: Colors.red, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  };
  
  runApp(const ProviderScope(child: ShortVideoApp()));
}

class ShortVideoApp extends ConsumerWidget {
  const ShortVideoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Short Video',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: currentUser.when(
        data: (user) {
          if (user != null) {
            // After login, show video feed screen
            return const VideoFeedScreen();
          } else {
            return const LoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(currentUserProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoRepository {
  final _videosRef = FirebaseFirestore.instance.collection('videos');

  Future<List<VideoModel>> fetchVideos() async {
    final snapshot = await _videosRef.get();
    return snapshot.docs
        .map((doc) => VideoModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> likeVideo(String videoId) async {
    await _videosRef.doc(videoId).update({'likes': FieldValue.increment(1)});
  }

  // Add comment, share, upload, etc. as needed
}
