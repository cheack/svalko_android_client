import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/svalko_api.dart';
import '../../core/result.dart';

Future<bool> showNewPostSheet(
  BuildContext context,
  SvalkoApi api,
  Box<String> settingsBox,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NewPostSheet(api: api, settingsBox: settingsBox),
  );
  return result == true;
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet({required this.api, required this.settingsBox});

  final SvalkoApi api;
  final Box<String> settingsBox;

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  static const _authorKey = 'comment_author';

  final _authorCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  CommentFormData? _form;
  bool _formError = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final savedAuthor = widget.settingsBox.get(_authorKey);
    final hasSavedAuthor = savedAuthor != null;
    if (hasSavedAuthor) {
      _authorCtrl.text = savedAuthor;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focusNode.requestFocus());
    }
    _loadForm(hasSavedAuthor: hasSavedAuthor);
  }

  Future<void> _loadForm({required bool hasSavedAuthor}) async {
    final result = await widget.api.fetchPostForm();
    if (!mounted) return;
    if (result is Err) {
      setState(() => _formError = true);
      return;
    }
    final form = (result as Ok<CommentFormData, AppError>).value;
    setState(() => _form = form);
    if (!hasSavedAuthor) {
      _authorCtrl.text = form.suggestedAuthor;
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _authorCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _wrapSelection(String tag) {
    final text = _textCtrl.text;
    final sel = _textCtrl.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final selected = text.substring(start, end);
    final open = '[$tag]';
    final close = '[/$tag]';
    _textCtrl.value = TextEditingValue(
      text: text.replaceRange(start, end, '$open$selected$close'),
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + open.length)
          : TextSelection(
              baseOffset: start + open.length,
              extentOffset: start + open.length + selected.length,
            ),
    );
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final form = _form;
    if (form == null) return;

    final author = _authorCtrl.text.trim().isEmpty
        ? form.suggestedAuthor
        : _authorCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    widget.settingsBox.put(_authorKey, author);

    final result = await widget.api.submitPost(
      author: author,
      text: text,
      form: form,
    );
    if (!mounted) return;
    if (result is Err) {
      setState(() {
        _submitting = false;
        _submitError = 'Ошибка отправки';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  bool get _formReady => _form != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final savedAuthor = widget.settingsBox.get(_authorKey);

    if (savedAuthor == null && !_formReady && !_formError) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorLabel(controller: _authorCtrl, theme: theme),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (tag, label, style) in [
                ('b', 'B', TextStyle(fontWeight: FontWeight.bold)),
                ('i', 'I', TextStyle(fontStyle: FontStyle.italic)),
                ('u', 'U', TextStyle(decoration: TextDecoration.underline)),
                ('s', 'S', TextStyle(decoration: TextDecoration.lineThrough)),
              ])
                SizedBox(
                  width: 36,
                  height: 32,
                  child: TextButton(
                    onPressed: () => _wrapSelection(tag),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(label, style: style),
                  ),
                ),
            ],
          ),
          Flexible(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              minLines: 4,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              expands: false,
              contextMenuBuilder: (context, editableTextState) {
                final selection = editableTextState.textEditingValue.selection;
                final hasSelection = selection.isValid && !selection.isCollapsed;
                final items = [
                  if (hasSelection) ...[
                    for (final (tag, label) in [
                      ('b', 'Жирный'),
                      ('i', 'Курсив'),
                      ('u', 'Подчёрк'),
                      ('s', 'Зачёрк'),
                    ])
                      ContextMenuButtonItem(
                        label: label,
                        onPressed: () {
                          ContextMenuController.removeAny();
                          _wrapSelection(tag);
                        },
                      ),
                  ],
                  ...editableTextState.contextMenuButtonItems,
                ];
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: items,
                );
              },
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 6),
            Text(_submitError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_formError) ...[
            const SizedBox(height: 6),
            Text('Не удалось загрузить форму',
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_submitting || !_formReady) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Да!'),
          ),
        ],
      ),
    );
  }
}

class _AuthorLabel extends StatelessWidget {
  const _AuthorLabel({required this.controller, required this.theme});

  final TextEditingController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Я, ', style: theme.textTheme.bodyMedium),
        Flexible(
          child: IntrinsicWidth(
            child: TextField(
              controller: controller,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
                border: UnderlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
        Text(', хочу послать нижеследующее:', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
