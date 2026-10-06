import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'post_form_shared.dart';

class Attachment {
  Attachment({this.localPath});
  final String? localPath;
  /// Null while uploading. `code` is the text inserted into the post.
  UploadedFile? uploaded;
  String? uploadError;
  double progress = 0;
  bool removing = false;

  bool get isUploading => localPath != null && uploaded == null && uploadError == null;
}

/// Persists the successfully uploaded attachments under [key], so they
/// survive the form being closed by accident.
void saveAttachments(Box<String> box, String key, List<Attachment> attachments) {
  final data = attachments
      .where((a) => a.uploaded != null && a.uploaded!.code.isNotEmpty)
      .map((a) => {
            'code': a.uploaded!.code,
            'deleteParam': a.uploaded!.deleteParam,
            if (a.localPath != null) 'localPath': a.localPath,
          })
      .toList();
  box.put(key, jsonEncode(data));
}

/// Inverse of [saveAttachments]. [fallbackPath] supplies a local preview path
/// for entries saved without one. Previews whose file is gone are dropped.
List<Attachment> restoreAttachments(
  Box<String> box,
  String key, {
  String? Function(String code)? fallbackPath,
}) {
  final saved = box.get(key);
  if (saved == null) return [];
  return [
    for (final item in jsonDecode(saved) as List<dynamic>)
      () {
        final code = item['code'] as String;
        final path = (item['localPath'] as String?) ?? fallbackPath?.call(code);
        return Attachment(localPath: path != null && File(path).existsSync() ? path : null)
          ..uploaded = UploadedFile(code: code, deleteParam: item['deleteParam'] as String);
      }(),
  ];
}

/// Fades an attachment out before the caller removes it from its list.
/// Returns false if the owning state was disposed meanwhile.
Future<bool> animateAttachmentRemoval(
  Attachment attachment,
  void Function(VoidCallback) setState,
  bool Function() isMounted,
) async {
  setState(() => attachment.removing = true);
  await Future.delayed(const Duration(milliseconds: 250));
  return isMounted();
}

/// Horizontal strip with the "add image" button followed by attachment tiles.
class AttachmentRow extends StatelessWidget {
  const AttachmentRow({
    super.key,
    required this.attachments,
    required this.canAdd,
    required this.onAdd,
    required this.onInsert,
    required this.onDelete,
  });

  final List<Attachment> attachments;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(Attachment) onInsert;
  final void Function(Attachment) onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddImageButton(enabled: canAdd, onTap: onAdd),
          for (final a in attachments)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: a.removing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AttachmentTile(
                  attachment: a,
                  onInsert: a.uploaded != null && !a.removing ? () => onInsert(a) : null,
                  onDelete: () => onDelete(a),
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
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.attachment,
    required this.onInsert,
    required this.onDelete,
    this.onError,
  });

  final Attachment attachment;
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

class AddImageButton extends StatelessWidget {
  const AddImageButton({super.key, required this.enabled, required this.onTap});

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

