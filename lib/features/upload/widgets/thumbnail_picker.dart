import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ThumbnailPicker extends StatelessWidget {
  final void Function(String) onThumbnailSelected;
  const ThumbnailPicker({Key? key, required this.onThumbnailSelected}) : super(key: key);

  Future<void> _pickImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      onThumbnailSelected(result.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () {
            // TODO: Extract frame from video and call onThumbnailSelected
          },
          child: const Text('Pick Frame'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _pickImage(context),
          child: const Text('Upload Image'),
        ),
      ],
    );
  }
} 