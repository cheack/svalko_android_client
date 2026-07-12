import 'package:flutter/material.dart';
import 'comment_html.dart';

/// A height-clamped [CommentHtml], for previews (compact comment tiles, the
/// last-comments list) that shouldn't grow to the full comment length.
class CommentPreview extends StatelessWidget {
  const CommentPreview(
    this.html, {
    super.key,
    this.maxLines = 5,
    this.onSvalkoPost,
  });

  final String html;
  final int maxLines;
  final void Function(int postId)? onSvalkoPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.textScalerOf(context).scale(
                theme.textTheme.bodyMedium?.fontSize ?? 14,
              ) *
              1.45 *
              maxLines,
        ),
        child: CommentHtml(html, compact: true, onSvalkoPost: onSvalkoPost),
      ),
    );
  }
}
