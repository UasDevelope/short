import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/video_model.dart';
import '../features/upload/video_editing_controller.dart';

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload video to Firebase Storage
  Future<String> uploadVideo(File videoFile, String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storageRef = _storage.ref().child('videos/$videoId.mp4');
      final uploadTask = storageRef.putFile(videoFile);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  // Upload thumbnail to Firebase Storage
  Future<String?> uploadThumbnail(File thumbnailFile, String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storageRef = _storage.ref().child('thumbnails/$videoId.jpg');
      final uploadTask = storageRef.putFile(thumbnailFile);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Failed to upload thumbnail: $e');
      return null;
    }
  }

  // Save video metadata to Firestore
  Future<void> saveVideoMetadata({
    required String videoUrl,
    required String caption,
    required List<String> hashtags,
    String? thumbnailUrl,
    String? music,
    required PrivacySetting privacy,
    required bool allowComments,
    required bool allowSharing,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final videoData = {
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'hashtags': hashtags,
        'music': music ?? 'Original Audio',
        'username': user.email?.split('@')[0] ?? 'Anonymous',
        'userId': user.uid,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'privacy': privacy.toString(),
        'allowComments': allowComments,
        'allowSharing': allowSharing,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('videos').add(videoData);
    } catch (e) {
      throw Exception('Failed to save video metadata: $e');
    }
  }

  // Complete video upload process
  Future<void> uploadVideoComplete({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    File? thumbnailFile,
    String? music,
    required PrivacySetting privacy,
    required bool allowComments,
    required bool allowSharing,
    required Function(double) onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Generate unique video ID
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      onProgress(0.1); // 10% - Starting upload

      // Upload video to Firebase Storage
      final videoUrl = await uploadVideo(videoFile, videoId);
      onProgress(0.6); // 60% - Video uploaded

      // Upload thumbnail if provided
      String? thumbnailUrl;
      if (thumbnailFile != null) {
        thumbnailUrl = await uploadThumbnail(thumbnailFile, videoId);
        onProgress(0.8); // 80% - Thumbnail uploaded
      }

      // Save metadata to Firestore
      await saveVideoMetadata(
        videoUrl: videoUrl,
        caption: caption,
        hashtags: hashtags,
        thumbnailUrl: thumbnailUrl,
        music: music,
        privacy: privacy,
        allowComments: allowComments,
        allowSharing: allowSharing,
      );
      
      onProgress(1.0); // 100% - Complete
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }
}

// Provider for UploadService
final uploadServiceProvider = Provider<UploadService>((ref) => UploadService()); 