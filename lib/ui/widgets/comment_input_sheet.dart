import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/svalko_api.dart';
import '../../core/result.dart';
import 'author_label.dart';
import 'attachment_widgets.dart';
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
      settings: const RouteSettings(name: '/comment'),
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
  bool _picking = false;
  String? _submitError;

  final _attachments = <Attachment>[];
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
    final restored = restoreAttachments(
      widget.settingsBox,
      _attachmentsKey,
      fallbackPath: (code) => widget.settingsBox.get('img_cache_$code'),
    );
    _attachments.addAll(restored);
    _knownCodes.addAll(restored.map((a) => a.uploaded!.code));
  }

  void _saveAttachments() => saveAttachments(widget.settingsBox, _attachmentsKey, _attachments);

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
    if (form == null || _picking) return;
    setState(() => _picking = true);

    try {
    final file = await FilePicker.pickFile(
      type: FileType.image,
      compressionQuality: 0,
    );
    if (file == null || file.path == null) return;

    final path = file.path!;
    final attachment = Attachment(localPath: path);
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
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _delete(Attachment attachment) async {
    final form = _form;
    final uploaded = attachment.uploaded;

    if (!await animateAttachmentRemoval(attachment, setState, () => mounted)) return;

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

  void _insertCode(String code) => insertAtCursor(code, _textCtrl, _focusNode);

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
          AttachmentRow(
            attachments: _attachments,
            canAdd: _formReady && !_hasUploading,
            onAdd: _pickAndUpload,
            onInsert: (a) => _insertCode(a.uploaded!.code),
            onDelete: _delete,
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
