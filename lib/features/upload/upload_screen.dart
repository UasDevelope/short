import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'video_editing_controller.dart';
import 'widgets/video_picker_widget.dart';
import 'widgets/filter_selector.dart';
import 'widgets/music_selector.dart';
import 'widgets/overlay_editor.dart';
import 'widgets/thumbnail_picker.dart';
import 'widgets/caption_hashtag_input.dart';
import 'widgets/privacy_settings.dart';
import 'widgets/video_trimmer_widget.dart';
import '../../services/upload_service.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  int _currentStep = 0;
  final List<String> _filters = ['None', 'Vintage', 'Black & White', 'Sepia', 'Bright', 'Contrast'];
  final List<String> _builtInMusic = ['Original Audio', 'Trending Beat', 'Chill Vibes', 'Upbeat'];

  @override
  Widget build(BuildContext context) {
    final editingState = ref.watch(videoEditingControllerProvider);
    final controller = ref.watch(videoEditingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => _uploadVideo(controller),
              child: const Text('Upload', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 8) setState(() => _currentStep++);
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        steps: [
          Step(
            title: const Text('Select/Record Video'),
            content: _buildVideoPickerStep(controller),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Edit Video'),
            content: _buildVideoEditorStep(editingState, controller),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Apply Filters'),
            content: _buildFilterStep(editingState, controller),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: const Text('Add Music'),
            content: _buildMusicStep(editingState, controller),
            isActive: _currentStep >= 3,
          ),
          Step(
            title: const Text('Text & Stickers'),
            content: _buildOverlayStep(editingState, controller),
            isActive: _currentStep >= 4,
          ),
          Step(
            title: const Text('Thumbnail'),
            content: _buildThumbnailStep(editingState, controller),
            isActive: _currentStep >= 5,
          ),
          Step(
            title: const Text('Caption & Hashtags'),
            content: _buildCaptionStep(editingState, controller),
            isActive: _currentStep >= 6,
          ),
          Step(
            title: const Text('Privacy Settings'),
            content: _buildPrivacyStep(editingState, controller),
            isActive: _currentStep >= 7,
          ),
          Step(
            title: const Text('Upload'),
            content: _buildUploadStep(editingState, controller),
            isActive: _currentStep >= 8,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPickerStep(VideoEditingController controller) {
    return VideoPickerWidget(
      onVideoPicked: (videoFile) {
        if (videoFile != null) {
          controller.setVideoFile(File(videoFile.path));
          setState(() => _currentStep++);
        }
      },
      maxDurationSeconds: 60,
    );
  }

  Widget _buildVideoEditorStep(VideoEditingState state, VideoEditingController controller) {
    if (state.videoFile == null) {
      return const Text('Please select a video first');
    }

    return SizedBox(
      height: 400,
      child: VideoTrimmerWidget(
        videoPath: state.videoFile!.path,
        onVideoTrimmed: (editedPath, start, end) {
          controller.setEditedVideo(editedPath, start, end);
        },
      ),
    );
  }

  Widget _buildFilterStep(VideoEditingState state, VideoEditingController controller) {
    return FilterSelector(
      filters: _filters,
      selectedFilter: state.filter,
      onFilterSelected: (filter) {
        controller.setFilter(filter);
      },
    );
  }

  Widget _buildMusicStep(VideoEditingState state, VideoEditingController controller) {
    return MusicSelector(
      builtInMusic: _builtInMusic,
      onMusicSelected: (musicPath) {
        controller.setMusic(musicPath);
      },
    );
  }

  Widget _buildOverlayStep(VideoEditingState state, VideoEditingController controller) {
    return OverlayEditor(
      overlays: state.overlays,
      onOverlaysChanged: (overlays) {
        // Update overlays in controller
        for (final overlay in overlays) {
          controller.addOverlay(overlay);
        }
      },
    );
  }

  Widget _buildThumbnailStep(VideoEditingState state, VideoEditingController controller) {
    return ThumbnailPicker(
      onThumbnailSelected: (thumbnailPath) {
        controller.setThumbnail(thumbnailPath);
      },
    );
  }

  Widget _buildCaptionStep(VideoEditingState state, VideoEditingController controller) {
    return CaptionHashtagInput(
      caption: state.caption,
      hashtags: state.hashtags,
      onChanged: (caption, hashtags) {
        controller.setCaption(caption);
        controller.setHashtags(hashtags);
      },
    );
  }

  Widget _buildPrivacyStep(VideoEditingState state, VideoEditingController controller) {
    return PrivacySettingsWidget(
      privacy: state.privacy,
      allowComments: state.allowComments,
      allowSharing: state.allowSharing,
      onChanged: (privacy, allowComments, allowSharing) {
        controller.setPrivacySettings(privacy, allowComments, allowSharing);
      },
    );
  }

  Widget _buildUploadStep(VideoEditingState state, VideoEditingController controller) {
    return Column(
      children: [
        LinearProgressIndicator(value: state.uploadProgress),
        const SizedBox(height: 16),
        Text('Upload Progress: ${(state.uploadProgress * 100).toInt()}%'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: state.uploadProgress == 0.0 ? () => _uploadVideo(controller) : null,
          child: const Text('Start Upload'),
        ),
      ],
    );
  }

  Future<void> _uploadVideo(VideoEditingController controller) async {
    final state = ref.read(videoEditingControllerProvider);
    
    if (state.videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    try {
      final uploadService = ref.read(uploadServiceProvider);
      
      await uploadService.uploadVideoComplete(
        videoFile: state.videoFile!,
        caption: state.caption ?? '',
        hashtags: state.hashtags,
        thumbnailFile: state.thumbnailPath != null ? File(state.thumbnailPath!) : null,
        music: state.musicPath,
        privacy: state.privacy,
        allowComments: state.allowComments,
        allowSharing: state.allowSharing,
        onProgress: (progress) {
          controller.setUploadProgress(progress);
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video uploaded successfully to Firebase!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset and go back to feed
      controller.reset();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 