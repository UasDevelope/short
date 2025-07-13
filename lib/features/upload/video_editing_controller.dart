import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoEditingState {
  final File? videoFile;
  final String? editedVideoPath;
  final Duration? trimStart;
  final Duration? trimEnd;
  final String? filter;
  final String? musicPath;
  final double musicVolume;
  final List<OverlayData> overlays;
  final String? thumbnailPath;
  final String? caption;
  final List<String> hashtags;
  final PrivacySetting privacy;
  final bool allowComments;
  final bool allowSharing;
  final double uploadProgress;
  final bool isEditing;

  VideoEditingState({
    this.videoFile,
    this.editedVideoPath,
    this.trimStart,
    this.trimEnd,
    this.filter,
    this.musicPath,
    this.musicVolume = 1.0,
    this.overlays = const [],
    this.thumbnailPath,
    this.caption,
    this.hashtags = const [],
    this.privacy = PrivacySetting.public,
    this.allowComments = true,
    this.allowSharing = true,
    this.uploadProgress = 0.0,
    this.isEditing = false,
  });

  VideoEditingState copyWith({
    File? videoFile,
    String? editedVideoPath,
    Duration? trimStart,
    Duration? trimEnd,
    String? filter,
    String? musicPath,
    double? musicVolume,
    List<OverlayData>? overlays,
    String? thumbnailPath,
    String? caption,
    List<String>? hashtags,
    PrivacySetting? privacy,
    bool? allowComments,
    bool? allowSharing,
    double? uploadProgress,
    bool? isEditing,
  }) {
    return VideoEditingState(
      videoFile: videoFile ?? this.videoFile,
      editedVideoPath: editedVideoPath ?? this.editedVideoPath,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      filter: filter ?? this.filter,
      musicPath: musicPath ?? this.musicPath,
      musicVolume: musicVolume ?? this.musicVolume,
      overlays: overlays ?? this.overlays,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      privacy: privacy ?? this.privacy,
      allowComments: allowComments ?? this.allowComments,
      allowSharing: allowSharing ?? this.allowSharing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

class OverlayData {
  final String type; // 'text', 'sticker', etc.
  final String content;
  final double x, y, scale, rotation;
  final Duration start, end;
  OverlayData({
    required this.type,
    required this.content,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
    required this.start,
    required this.end,
  });
}

enum PrivacySetting { public, followers, private }

final videoEditingControllerProvider = StateNotifierProvider<VideoEditingController, VideoEditingState>((ref) {
  return VideoEditingController();
});

class VideoEditingController extends StateNotifier<VideoEditingState> {
  VideoEditingController() : super(VideoEditingState());

  void setVideoFile(File videoFile) {
    state = state.copyWith(videoFile: videoFile);
  }

  void setEditedVideo(String editedPath, Duration start, Duration end) {
    state = state.copyWith(
      editedVideoPath: editedPath,
      trimStart: start,
      trimEnd: end,
    );
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  void setMusic(String musicPath, {double volume = 1.0}) {
    state = state.copyWith(
      musicPath: musicPath,
      musicVolume: volume,
    );
  }

  void addOverlay(OverlayData overlay) {
    final overlays = List<OverlayData>.from(state.overlays)..add(overlay);
    state = state.copyWith(overlays: overlays);
  }

  void removeOverlay(int index) {
    final overlays = List<OverlayData>.from(state.overlays)..removeAt(index);
    state = state.copyWith(overlays: overlays);
  }

  void setThumbnail(String thumbnailPath) {
    state = state.copyWith(thumbnailPath: thumbnailPath);
  }

  void setCaption(String caption) {
    state = state.copyWith(caption: caption);
  }

  void setHashtags(List<String> hashtags) {
    state = state.copyWith(hashtags: hashtags);
  }

  void setPrivacySettings(PrivacySetting privacy, bool allowComments, bool allowSharing) {
    state = state.copyWith(
      privacy: privacy,
      allowComments: allowComments,
      allowSharing: allowSharing,
    );
  }

  void setUploadProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  void setEditing(bool isEditing) {
    state = state.copyWith(isEditing: isEditing);
  }

  void reset() {
    state = VideoEditingState();
  }
} 