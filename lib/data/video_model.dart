import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String url;
  final String username;
  final String caption;
  final String music;
  final int likes;
  final int comments;
  final int shares;
  final List<String> hashtags;

  VideoModel({
    required this.id,
    required this.url,
    required this.username,
    required this.caption,
    required this.music,
    required this.likes,
    required this.comments,
    required this.shares,
    this.hashtags = const [],
  });

  factory VideoModel.fromMap(Map<String, dynamic> map, String id) {
    return VideoModel(
      id: id,
      url: map['url'] ?? '',
      username: map['username'] ?? '',
      caption: map['caption'] ?? '',
      music: map['music'] ?? '',
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      hashtags: List<String>.from(map['hashtags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'username': username,
      'caption': caption,
      'music': music,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'hashtags': hashtags,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
} 