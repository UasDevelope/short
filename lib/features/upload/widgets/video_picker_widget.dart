import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoPickerWidget extends StatelessWidget {
  final void Function(XFile?) onVideoPicked;
  final int maxDurationSeconds;
  const VideoPickerWidget({Key? key, required this.onVideoPicked, this.maxDurationSeconds = 60}) : super(key: key);

  Future<void> _pickVideo(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: source,
      maxDuration: Duration(seconds: maxDurationSeconds),
    );
    onVideoPicked(video);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.video_library),
          label: const Text('Gallery'),
          onPressed: () => _pickVideo(context, ImageSource.gallery),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.videocam),
          label: const Text('Record'),
          onPressed: () => _pickVideo(context, ImageSource.camera),
        ),
      ],
    );
  }
} 