import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/subtask.dart';

class SubtaskTile extends StatefulWidget {
  const SubtaskTile({
    super.key,
    required this.subtask,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final Subtask subtask;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  @override
  State<SubtaskTile> createState() => _SubtaskTileState();
}

class _SubtaskTileState extends State<SubtaskTile> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.subtask.title);
  }

  @override
  void didUpdateWidget(covariant SubtaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtask.title != widget.subtask.title && !_editing) {
      _controller.text = widget.subtask.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(widget.subtask.id),
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: widget.subtask.isDone,
        onChanged: (value) {
          if (value != null) widget.onToggle(value);
        },
      ),
      title: _editing
          ? TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Subtask title',
              ),
            )
          : GestureDetector(
              onTap: () => setState(() {
                _editing = true;
                _controller.text = widget.subtask.title;
              }),
              child: Text(
                widget.subtask.title,
                style: TextStyle(
                  decoration: widget.subtask.isDone
                      ? TextDecoration.lineThrough
                      : null,
                  color: widget.subtask.isDone
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing)
            IconButton(
              tooltip: 'Save subtask',
              onPressed: _save,
              icon: const Icon(Icons.check),
            )
          else
            IconButton(
              tooltip: 'Rename subtask',
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Delete subtask',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty && title != widget.subtask.title) {
      widget.onRename(title);
    }
    setState(() => _editing = false);
  }
}
