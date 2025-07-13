import 'package:flutter/material.dart';
import '../video_editing_controller.dart';

class PrivacySettingsWidget extends StatelessWidget {
  final PrivacySetting privacy;
  final bool allowComments;
  final bool allowSharing;
  final void Function(PrivacySetting, bool, bool) onChanged;
  const PrivacySettingsWidget({Key? key, required this.privacy, required this.allowComments, required this.allowSharing, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<PrivacySetting>(
          value: privacy,
          items: PrivacySetting.values.map((p) => DropdownMenuItem(
            value: p,
            child: Text(p.toString().split('.').last),
          )).toList(),
          onChanged: (p) {
            if (p != null) onChanged(p, allowComments, allowSharing);
          },
        ),
        SwitchListTile(
          title: const Text('Allow Comments'),
          value: allowComments,
          onChanged: (v) => onChanged(privacy, v, allowSharing),
        ),
        SwitchListTile(
          title: const Text('Allow Sharing'),
          value: allowSharing,
          onChanged: (v) => onChanged(privacy, allowComments, v),
        ),
      ],
    );
  }
} 