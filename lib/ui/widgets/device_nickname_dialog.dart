import 'package:flutter/material.dart';


/// Dialog for editing device nickname
class DeviceNicknameDialog extends StatefulWidget {
  final String deviceName;
  final String? currentNickname;
  final Function(String?) onSave;

  const DeviceNicknameDialog({
    super.key,
    required this.deviceName,
    this.currentNickname,
    required this.onSave,
  });

  @override
  State<DeviceNicknameDialog> createState() => _DeviceNicknameDialogState();
}

class _DeviceNicknameDialogState extends State<DeviceNicknameDialog> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname ?? '');
    _controller.addListener(() {
      setState(() {
        _hasChanges = _controller.text.trim() != (widget.currentNickname ?? '');
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Device Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original: ${widget.deviceName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: 'Custom Name',
              hintText: 'Enter a custom name',
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                      },
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.currentNickname != null)
          TextButton(
            onPressed: () {
              widget.onSave(null); // Clear nickname
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hasChanges ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final nickname = _controller.text.trim();
    widget.onSave(nickname.isEmpty ? null : nickname);
    Navigator.of(context).pop();
  }
}
