import 'package:flutter/material.dart';

class CaptionHashtagInput extends StatefulWidget {
  final String? caption;
  final List<String> hashtags;
  final void Function(String, List<String>) onChanged;
  const CaptionHashtagInput({Key? key, this.caption, this.hashtags = const [], required this.onChanged}) : super(key: key);

  @override
  State<CaptionHashtagInput> createState() => _CaptionHashtagInputState();
}

class _CaptionHashtagInputState extends State<CaptionHashtagInput> {
  late TextEditingController _captionController;
  late List<String> _hashtags;
  final List<String> _suggestions = ['#fun', '#music', '#dance', '#comedy', '#trending'];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.caption);
    _hashtags = List.from(widget.hashtags);
  }

  void _addHashtag(String tag) {
    if (!_hashtags.contains(tag)) {
      setState(() => _hashtags.add(tag));
      widget.onChanged(_captionController.text, _hashtags);
    }
  }

  void _removeHashtag(String tag) {
    setState(() => _hashtags.remove(tag));
    widget.onChanged(_captionController.text, _hashtags);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _captionController,
          decoration: const InputDecoration(labelText: 'Caption'),
          onChanged: (v) => widget.onChanged(v, _hashtags),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _hashtags.map((tag) => Chip(
            label: Text(tag),
            onDeleted: () => _removeHashtag(tag),
          )).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _suggestions.map((tag) => ActionChip(
            label: Text(tag),
            onPressed: () => _addHashtag(tag),
          )).toList(),
        ),
      ],
    );
  }
} 