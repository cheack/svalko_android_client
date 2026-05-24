import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config.dart';
import '../../../core/open_url.dart';
import '../../../models/comment.dart';
import '../../../ui/widgets/image_viewer.dart';
import '../../../ui/widgets/comment_html.dart';
import '../../../ui/widgets/media_actions.dart';
import '../../../ui/widgets/shimmer_placeholder.dart';
import '../../../ui/widgets/video_player_widget.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  String _commentUrl() =>
      '${Config.baseUrl}/${comment.postId}.html#c${comment.id}';

  bool _hasComplexStyles() =>
      comment.text?.contains('transform') == true;

  void _showCommentMenu(BuildContext context) {
    final url = _commentUrl();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser_outlined),
              title: const Text('Открыть в браузере'),
              onTap: () {
                Navigator.pop(ctx);
                openInBrowser(context, url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Скопировать ссылку'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: url));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComplexStylesInfo(BuildContext context) {
    final url = _commentUrl();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Этот комментарий содержит стили, которые невозможно отобразить правильно.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser_outlined),
              title: const Text('Открыть в браузере'),
              onTap: () {
                Navigator.pop(ctx);
                openInBrowser(context, url);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasComplex = _hasComplexStyles();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pushNamed('/author', arguments: comment.author),
                  child: Text(
                    comment.author.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDate(comment.publishedAt),
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showCommentMenu(context),
                child: Text(
                  '#${comment.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.outline,
                  ),
                ),
              ),
              if (hasComplex) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showComplexStylesInfo(context),
                  child: Icon(Icons.info_outline,
                      size: 14, color: theme.colorScheme.outline),
                ),
              ],
            ],
          ),
          if (comment.text != null && comment.text!.isNotEmpty) ...[
            const SizedBox(height: 4),
            CommentHtml(
              comment.text!,
              onSvalkoPost: (id) =>
                  Navigator.of(context).pushNamed('/post', arguments: id),
            ),
          ],
          for (final url in comment.imageUrls) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => showFullscreenImage(context, url),
              onLongPress: () => showMediaSheet(context, url),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const ShimmerPlaceholder(),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          for (final url in comment.videoUrls) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onLongPress: () => showMediaSheet(context, url, isVideo: true),
              child: VideoPlayerWidget(url: url),
            ),
          ],
          const Divider(height: 12),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
