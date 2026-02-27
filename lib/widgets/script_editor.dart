import 'package:flutter/material.dart';

/// Éditeur de script avec suggestions
class ScriptEditor extends StatefulWidget {
  final String initialScript;
  final ValueChanged<String> onChanged;

  const ScriptEditor({
    super.key,
    required this.initialScript,
    required this.onChanged,
  });

  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends State<ScriptEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialScript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Décrivez votre montage ici...',
            border: OutlineInputBorder(),
            helperText: 'Décrivez le montage en langage naturel',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSuggestionChip('Commence avec'),
            _buildSuggestionChip('pendant X secondes'),
            _buildSuggestionChip('ajoute une transition fade'),
            _buildSuggestionChip('puis affiche'),
            _buildSuggestionChip('musique de fond'),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        final currentText = _controller.text;
        final newText = currentText.isEmpty
            ? text
            : currentText.endsWith(' ')
                ? '$currentText$text'
                : '$currentText $text';
        _controller.text = newText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        widget.onChanged(newText);
      },
    );
  }
}
