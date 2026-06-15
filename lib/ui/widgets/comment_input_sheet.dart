import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/svalko_api.dart';
import '../../core/result.dart';
import 'author_label.dart';
import 'post_form_shared.dart';

/// Returns true if a comment was successfully submitted.
Future<bool> showCommentSheet(
  BuildContext context,
  SvalkoApi api,
  Box<String> settingsBox,
  int postId,
) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CommentScreen(
        api: api,
        settingsBox: settingsBox,
        postId: postId,
      ),
    ),
  );
  return result == true;
}

class _CommentScreen extends StatelessWidget {
  const _CommentScreen({required this.api, required this.settingsBox, required this.postId});
  final SvalkoApi api;
  final Box<String> settingsBox;
  final int postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Написать')),
      body: _CommentSheet(api: api, settingsBox: settingsBox, postId: postId),
    );
  }
}

class _Attachment {
  _Attachment({this.localPath});
  final String? localPath;
  UploadedFile? uploaded;  // null while uploading a new file
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
  static const _draftKey = 'comment_draft';
  static const _attachmentsKey = 'comment_attachments';

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
    restoreAndTrackDraft(_textCtrl, widget.settingsBox, _draftKey);
    _restoreAttachments();
    _loadForm(hasSavedAuthor: hasSavedAuthor);
  }

  void _restoreAttachments() {
    final saved = widget.settingsBox.get(_attachmentsKey);
    if (saved == null) return;
    final list = jsonDecode(saved) as List<dynamic>;
    for (final item in list) {
      final code = item['code'] as String;
      final deleteParam = item['deleteParam'] as String;
      final cachedPath = widget.settingsBox.get('img_cache_$code');
      final localPath = cachedPath != null && File(cachedPath).existsSync() ? cachedPath : null;
      _knownCodes.add(code);
      _attachments.add(_Attachment(localPath: localPath)..uploaded = UploadedFile(code: code, deleteParam: deleteParam));
    }
  }

  void _saveAttachments() {
    final data = _attachments
        .where((a) => a.uploaded != null && a.uploaded!.code.isNotEmpty)
        .map((a) => {'code': a.uploaded!.code, 'deleteParam': a.uploaded!.deleteParam})
        .toList();
    widget.settingsBox.put(_attachmentsKey, jsonEncode(data));
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

  Future<void> _pickAndUpload() async {
    final form = _form;
    if (form == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      compressionQuality: 0,
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
    final files = parseUploadedFiles(html);
    // The new file is the one not yet in _knownCodes.
    final newFile = files.where((f) => !_knownCodes.contains(f.code)).firstOrNull;
    if (newFile == null) {
      setState(() => attachment.uploadError = 'Не удалось загрузить');
      return;
    }

    setState(() {
      attachment.uploaded = newFile;
      for (final f in files) {
        _knownCodes.add(f.code);
      }
    });
    widget.settingsBox.put('img_cache_${newFile.code}', path);
    _saveAttachments();
  }

  Future<void> _delete(_Attachment attachment) async {
    final form = _form;
    final uploaded = attachment.uploaded;

    setState(() => attachment.removing = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    setState(() => _attachments.remove(attachment));
    _saveAttachments();

    if (form == null || uploaded == null) return;
    _knownCodes.remove(uploaded.code);
    await widget.api.deleteUploadedFile(
      uploadId: form.uploadId,
      uploadKey: form.uploadKey,
      cookie: form.cookie,
      deleteParam: uploaded.deleteParam,
    );
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

    await saveAuthorCookie(widget.settingsBox, widget.api, _authorKey, author);

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

    clearDraft(widget.settingsBox, _draftKey);
    widget.settingsBox.delete(_attachmentsKey);
    Navigator.of(context).pop(true);
  }

  bool get _formReady => _form != null;
  bool get _hasUploading => _attachments.any((a) => a.isUploading);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedAuthor = widget.settingsBox.get(_authorKey);

    if (savedAuthor == null && !_formReady && !_formError) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthorLabel(controller: _authorCtrl, theme: theme),
          const SizedBox(height: 8),
          BbCodeToolbar(onWrap: (tag) => wrapBbCode(tag, _textCtrl, _focusNode)),
          BbCodeTextField(
            controller: _textCtrl,
            focusNode: _focusNode,
            onWrap: (tag) => wrapBbCode(tag, _textCtrl, _focusNode),
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
                        onError: a.uploadError != null
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(a.uploadError!)),
                                )
                            : null,
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
    this.onError,
  });

  final _Attachment attachment;
  final VoidCallback? onInsert;
  final VoidCallback onDelete;
  final VoidCallback? onError;

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
                    child: GestureDetector(
                      onTap: onError,
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
            if (attachment.uploadError == null) ...[
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

