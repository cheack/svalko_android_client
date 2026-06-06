import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config.dart';
import '../../../core/open_url.dart';
import '../../../models/comment.dart';
import '../../../ui/skin_ext.dart';
import '../../../ui/widgets/image_viewer.dart';
import '../../../ui/widgets/comment_html.dart';
import '../../../ui/widgets/media_actions.dart';
import '../../../ui/widgets/image_carousel.dart';
import '../../../ui/widgets/shimmer_placeholder.dart';
import '../../../ui/widgets/video_player_widget.dart';

class CommentTile extends StatefulWidget {
  const CommentTile({super.key, required this.comment, this.isHighlighted = false});

  final Comment comment;
  final bool isHighlighted;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> with SingleTickerProviderStateMixin {
  AnimationController? _flashCtrl;
  Animation<double>? _flashAnim;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _flashCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      );
      _flashAnim = Tween<double>(begin: 0, end: 0.4).animate(
        CurvedAnimation(parent: _flashCtrl!, curve: Curves.easeInOut),
      );
      // Delay start until after the scroll animation completes (~650ms).
      Future.delayed(const Duration(milliseconds: 700), _runFlash);
    }
  }

  Future<void> _runFlash() async {
    final ctrl = _flashCtrl;
    if (ctrl == null) return;
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await ctrl.forward();
      if (!mounted) return;
      await ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _flashCtrl?.dispose();
    super.dispose();
  }

  Comment get comment => widget.comment;

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
    final cardPattern = theme.extension<SvalkoSkinExt>()?.cardPattern;

    final cs = theme.colorScheme;
    final dividers = theme.extension<SvalkoSkinExt>()?.cardDividers ?? false;
    final flashAnim = _flashAnim;
    return Padding(
      padding: dividers ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Stack(
        children: [
          Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          image: cardPattern,
          borderRadius: dividers ? null : BorderRadius.circular(4),
          border: dividers ? null : Border.all(color: cs.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkinHeader(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context)
                            .pushNamed('/author', arguments: comment.author),
                        child: Text(
                          comment.author.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.primary,
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
                          color: cs.outline,
                          decoration: TextDecoration.underline,
                          decorationColor: cs.outline,
                        ),
                      ),
                    ),
                    if (hasComplex) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showComplexStylesInfo(context),
                        child: Icon(Icons.info_outline,
                            size: 14, color: cs.outline),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.text != null && comment.text!.isNotEmpty) ...[
                    const SizedBox(height: 0),
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
                        child: MediaImage(
                          url: url,
                          fit: BoxFit.contain,
                          loadingWidget: const ShimmerPlaceholder(),
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
          if (flashAnim != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: flashAnim,
                  builder: (_, _) => ColoredBox(
                    color: cs.primary.withValues(alpha: flashAnim.value),
                  ),
                ),
              ),
            ),
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
