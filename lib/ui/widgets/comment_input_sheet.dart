import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../data/svalko_api.dart';
import '../../core/result.dart';

/// Returns true if a comment was successfully submitted.
Future<bool> showCommentSheet(
  BuildContext context,
  SvalkoApi api,
  Box<String> settingsBox,
  int postId,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CommentSheet(
      api: api,
      settingsBox: settingsBox,
      postId: postId,
    ),
  );
  return result == true;
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.api,
    required this.settingsBox,
    required this.postId,
  });

  final SvalkoApi api;
  final Box<String> settingsBox;
  final int postId;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  static const _authorKey = 'comment_author';

  final _authorCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // null while loading, Err if failed
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
    _loadForm(hasSavedAuthor: hasSavedAuthor);
  }

  Future<void> _loadForm({required bool hasSavedAuthor}) async {
    final result = await widget.api.fetchCommentForm(widget.postId);
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

  Future<void> _submit() async {
    final form = _form;
    if (form == null) return;

    final author = _authorCtrl.text.trim().isEmpty
        ? (form.suggestedAuthor)
        : _authorCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() { _submitting = true; _submitError = null; });

    widget.settingsBox.put(_authorKey, author);

    final result = await widget.api.submitComment(
      postId: widget.postId,
      author: author,
      text: text,
      form: form,
    );
    if (!mounted) return;
    if (result is Err) {
      setState(() { _submitting = false; _submitError = 'Ошибка отправки'; });
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

    // Show spinner only if we have no saved author and form isn't loaded yet
    if (savedAuthor == null && !_formReady && !_formError) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorLabel(controller: _authorCtrl, theme: theme),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            minLines: 5,
            maxLines: 12,
            textInputAction: TextInputAction.newline,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(_submitError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_formError) ...[
            const SizedBox(height: 8),
            Text('Не удалось загрузить форму', style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
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
