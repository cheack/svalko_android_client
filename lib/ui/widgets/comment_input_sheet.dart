import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

// Parses [:|uploadId.fileId|:] codes from upload handler HTML response.
// deleteParam is just the fileId integer — server expects ?delete=<fileId>.
List<_UploadedFile> _parseFiles(String html) {
  final re = RegExp(r'\[:\|(\d+)\.(\d+)\|:\]');
  return re
      .allMatches(html)
      .map((m) => _UploadedFile(
            code: m.group(0)!,        // [:|397988.2|:]
            deleteParam: m.group(2)!, // 2  (just the file ID)
          ))
      .toList();
}

class _UploadedFile {
  _UploadedFile({required this.code, required this.deleteParam});
  final String code;        // [:|397988.1|:]
  final String deleteParam; // 397988.1
}

class _Attachment {
  // localPath is null for files pre-existing on the server.
  _Attachment({this.localPath});
  final String? localPath;
  _UploadedFile? uploaded;  // null while uploading a new file
  String? uploadError;
  double progress = 0;
  bool removing = false;

  bool get isUploading => localPath != null && uploaded == null && uploadError == null;
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

  CommentFormData? _form;
  bool _formError = false;
  bool _submitting = false;
  String? _submitError;

  final _attachments = <_Attachment>[];
  // Codes already confirmed on server (to diff after next upload).
  final _knownCodes = <String>{};

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
    _loadExistingFiles(form);
  }

  Future<void> _loadExistingFiles(CommentFormData form) async {
    final result = await widget.api.fetchUploadedFilesList(
      uploadId: form.uploadId,
      uploadKey: form.uploadKey,
    );
    if (!mounted || result is Err) return;
    final html = (result as Ok<String, AppError>).value;
    final files = _parseFiles(html);
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        _knownCodes.add(f.code);
        final cachedPath = widget.settingsBox.get('img_cache_${f.code}');
        final attachment = _Attachment(
          localPath: cachedPath != null && File(cachedPath).existsSync()
              ? cachedPath
              : null,
        )..uploaded = f;
        _attachments.add(attachment);
      }
    });
  }

  @override
  void dispose() {
    _authorCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final form = _form;
    if (form == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final attachment = _Attachment(localPath: path);
    setState(() => _attachments.add(attachment));

    final uploadResult = await widget.api.uploadCommentImage(
      uploadId: form.uploadId,
      uploadKey: form.uploadKey,
      cookie: form.cookie,
      filePath: path,
      onProgress: (sent, total) {
        if (!mounted) return;
        setState(() => attachment.progress = total > 0 ? sent / total : 0);
      },
    );

    if (!mounted) return;

    if (uploadResult is Err) {
      setState(() => attachment.uploadError = 'Не удалось загрузить');
      return;
    }

    final html = (uploadResult as Ok<String, AppError>).value;
    final files = _parseFiles(html);
    // The new file is the one not yet in _knownCodes.
    final newFile = files.firstWhere(
      (f) => !_knownCodes.contains(f.code),
      orElse: () => files.isNotEmpty ? files.first : _UploadedFile(code: '', deleteParam: ''),
    );

    setState(() {
      attachment.uploaded = newFile;
      for (final f in files) {
        _knownCodes.add(f.code);
      }
    });
    if (newFile.code.isNotEmpty) {
      widget.settingsBox.put('img_cache_${newFile.code}', path);
    }
  }

  Future<void> _delete(_Attachment attachment) async {
    final form = _form;
    final uploaded = attachment.uploaded;

    setState(() => attachment.removing = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    setState(() => _attachments.remove(attachment));

    if (form == null || uploaded == null) return;
    _knownCodes.remove(uploaded.code);
    await widget.api.deleteUploadedFile(
      uploadId: form.uploadId,
      uploadKey: form.uploadKey,
      cookie: form.cookie,
      deleteParam: uploaded.deleteParam,
    );
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

  void _insertCode(String code) {
    final text = _textCtrl.text;
    final sel = _textCtrl.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final newText = text.replaceRange(start, end, code);
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + code.length),
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

    final result = await widget.api.submitComment(
      postId: widget.postId,
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
  bool get _hasUploading => _attachments.any((a) => a.isUploading);

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
        mainAxisSize: MainAxisSize.min,
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
          // Attachment row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddImageButton(
                  enabled: _formReady && !_hasUploading,
                  onTap: _pickAndUpload,
                ),
                for (final a in _attachments)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: a.removing ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _AttachmentTile(
                        attachment: a,
                        onInsert: a.uploaded != null && !a.removing
                            ? () => _insertCode(a.uploaded!.code)
                            : null,
                        onDelete: () => _delete(a),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_submitting || !_formReady || _hasUploading)
                ? null
                : _submit,
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

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onInsert,
    required this.onDelete,
  });

  final _Attachment attachment;
  final VoidCallback? onInsert;
  final VoidCallback onDelete;

  static const double _size = 80;

  static Widget _placeholder(ColorScheme colorScheme) => Container(
        color: colorScheme.surfaceContainerHigh,
        child: Icon(Icons.image_outlined, color: colorScheme.outline),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: SizedBox(
        width: _size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: attachment.localPath != null
                      ? Image.file(
                          File(attachment.localPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(colorScheme),
                        )
                      : _placeholder(colorScheme),
                  ),
                ),
                // Upload progress overlay
                if (attachment.isUploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              value: attachment.progress > 0
                                  ? attachment.progress
                                  : null,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Error overlay
                if (attachment.uploadError != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(Icons.error_outline,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                // Delete button (top-right)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              child: TextButton(
                onPressed: onInsert,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'В пост',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onInsert != null
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  static const double _size = 80;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? colorScheme.outline
                : colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: enabled ? colorScheme.primary : colorScheme.outlineVariant,
          size: 32,
        ),
      ),
    ));
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
