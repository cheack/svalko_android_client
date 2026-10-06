import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/fastpic_uploader.dart';
import '../../data/svalko_api.dart';
import '../../core/result.dart';
import 'attachment_widgets.dart';
import 'author_label.dart';
import 'post_form_shared.dart';

Future<bool> showNewPostSheet(
  BuildContext context,
  SvalkoApi api,
  Box<String> settingsBox,
) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NewPostScreen(api: api, settingsBox: settingsBox),
    ),
  );
  return result == true;
}

class _NewPostScreen extends StatelessWidget {
  const _NewPostScreen({required this.api, required this.settingsBox});
  final SvalkoApi api;
  final Box<String> settingsBox;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Написать')),
      body: _NewPostSheet(api: api, settingsBox: settingsBox),
    );
  }
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
  static const _draftKey = 'post_draft';
  static const _attachmentsKey = 'post_attachments';

  final _authorCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _fastpic = FastpicUploader();

  CommentFormData? _form;
  bool _formError = false;
  bool _submitting = false;
  String? _submitError;
  bool _picking = false;
  final _attachments = <Attachment>[];

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
    _attachments.addAll(restoreAttachments(widget.settingsBox, _attachmentsKey));
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

  void _saveAttachments() => saveAttachments(widget.settingsBox, _attachmentsKey, _attachments);

  bool get _hasUploading => _attachments.any((a) => a.isUploading);

  Future<void> _pickAndUpload() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      final path = file?.path;
      if (path == null || !mounted) return;

      final attachment = Attachment(localPath: path);
      setState(() => _attachments.add(attachment));

      final result = await _fastpic.upload(
        path,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => attachment.progress = total > 0 ? sent / total : 0);
        },
      );
      if (!mounted) return;

      setState(() {
        switch (result) {
          case Ok(:final value):
            attachment.uploaded = UploadedFile(code: value, deleteParam: '');
          case Err():
            attachment.uploadError = 'Не удалось загрузить';
        }
      });
      _saveAttachments();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _delete(Attachment attachment) async {
    if (!await animateAttachmentRemoval(attachment, setState, () => mounted)) return;
    setState(() => _attachments.remove(attachment));
    _saveAttachments();
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

    clearDraft(widget.settingsBox, _draftKey);
    widget.settingsBox.delete(_attachmentsKey);
    Navigator.of(context).pop(true);
  }

  bool get _formReady => _form != null;

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
            Text(_submitError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_formError) ...[
            const SizedBox(height: 6),
            Text('Не удалось загрузить форму',
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 10),
          AttachmentRow(
            attachments: _attachments,
            canAdd: !_hasUploading,
            onAdd: _pickAndUpload,
            onInsert: (a) => insertAtCursor('${a.uploaded!.code}\n', _textCtrl, _focusNode),
            onDelete: _delete,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_submitting || !_formReady || _hasUploading) ? null : _submit,
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
