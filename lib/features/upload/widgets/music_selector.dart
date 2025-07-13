import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class MusicSelector extends StatelessWidget {
  final List<String> builtInMusic;
  final void Function(String) onMusicSelected;
  const MusicSelector({Key? key, required this.builtInMusic, required this.onMusicSelected}) : super(key: key);

  Future<void> _pickLocalMusic(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      onMusicSelected(result.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...builtInMusic.map((m) => ListTile(
              title: Text(m),
              onTap: () => onMusicSelected(m),
            )),
        ElevatedButton.icon(
          icon: const Icon(Icons.library_music),
          label: const Text('Pick from device'),
          onPressed: () => _pickLocalMusic(context),
        ),
      ],
    );
  }
} 