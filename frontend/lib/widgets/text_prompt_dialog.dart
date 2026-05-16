import 'package:flutter/material.dart';

/// Simple dialog with one text field. Disposes its controller safely.
class TextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final TextCapitalization textCapitalization;

  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.confirmLabel = 'OK',
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        textCapitalization: widget.textCapitalization,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
