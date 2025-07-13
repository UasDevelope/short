import 'package:flutter/material.dart';
import '../video_editing_controller.dart';

class OverlayEditor extends StatefulWidget {
  final List<OverlayData> overlays;
  final void Function(List<OverlayData>) onOverlaysChanged;
  const OverlayEditor({Key? key, required this.overlays, required this.onOverlaysChanged}) : super(key: key);

  @override
  State<OverlayEditor> createState() => _OverlayEditorState();
}

class _OverlayEditorState extends State<OverlayEditor> {
  List<OverlayData> _overlays = [];

  @override
  void initState() {
    super.initState();
    _overlays = List.from(widget.overlays);
  }

  void _addTextOverlay() {
    setState(() {
      _overlays.add(OverlayData(
        type: 'text',
        content: 'New Text',
        x: 0.5,
        y: 0.5,
        scale: 1.0,
        rotation: 0.0,
        start: Duration.zero,
        end: const Duration(seconds: 5),
      ));
    });
    widget.onOverlaysChanged(_overlays);
  }

  void _addStickerOverlay() {
    setState(() {
      _overlays.add(OverlayData(
        type: 'sticker',
        content: '😀',
        x: 0.5,
        y: 0.5,
        scale: 1.0,
        rotation: 0.0,
        start: Duration.zero,
        end: const Duration(seconds: 5),
      ));
    });
    widget.onOverlaysChanged(_overlays);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: _addTextOverlay,
              child: const Text('Add Text'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addStickerOverlay,
              child: const Text('Add Sticker'),
            ),
          ],
        ),
        // For brevity, overlays are just listed here. In a real app, use a Stack for drag/resize.
        ..._overlays.map((o) => ListTile(
              title: Text('${o.type}: ${o.content}'),
              subtitle: Text('Pos: (${o.x}, ${o.y}), Scale: ${o.scale}, Rot: ${o.rotation}'),
            )),
      ],
    );
  }
} 