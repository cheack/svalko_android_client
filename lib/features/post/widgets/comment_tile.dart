import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config.dart';
import '../../../core/open_url.dart';
import '../../../features/favorites/favorites_storage.dart';
import '../../../models/comment.dart';
import '../../../ui/skin_ext.dart';
import '../../../ui/widgets/image_viewer.dart';
import '../../../ui/widgets/comment_html.dart';
import '../../../ui/widgets/kum_shake.dart';
import '../../../ui/widgets/media_actions.dart';
import '../../../ui/widgets/image_carousel.dart';
import '../../../ui/widgets/shimmer_placeholder.dart';
import '../../../ui/widgets/video_link_card.dart';
import '../../../ui/widgets/video_player_widget.dart';

class CommentTile extends ConsumerStatefulWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.currentPage,
    this.isHighlighted = false,
    this.compact = false,
    this.onTap,
    this.onDelete,
  });

  final Comment comment;
  final int currentPage;
  final bool isHighlighted;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> with SingleTickerProviderStateMixin {
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

  static final _videoLinkRe = RegExp(
    r'''href="([^"]*)"[^>]*class="[^"]*\bvideo\b'''
    r'''|'''
    r'''class="[^"]*\bvideo\b[^"]*"[^>]*href="([^"]*)"''',
    caseSensitive: false,
  );

  static List<String> _extractVideoLinks(String html) =>
      _videoLinkRe.allMatches(html)
          .map((m) => m.group(1) ?? m.group(2) ?? '')
          .where((url) => url.isNotEmpty)
          .toList();

  String _commentUrl() =>
      '${Config.baseUrl}/${comment.postId}.html#c${comment.id}';

  bool _hasComplexStyles() =>
      comment.text?.contains('transform') == true;

  void _showCommentMenu(BuildContext context) {
    final url = _commentUrl();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/comment-menu'),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
      ),
    );
  }

  void _showComplexStylesInfo(BuildContext context) {
    final url = _commentUrl();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/comment-styles'),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasComplex = _hasComplexStyles();
    final cs = theme.colorScheme;
    final dividers = theme.extension<SvalkoSkinExt>()?.cardDividers ?? false;
    final flashAnim = _flashAnim;
    final outerPadding = dividers
        ? (widget.compact && comment.isKum
            ? const EdgeInsets.symmetric(vertical: 6)
            : EdgeInsets.zero)
        : EdgeInsets.fromLTRB(
            8,
            widget.compact && comment.isKum ? 8 : 4,
            8,
            widget.compact && comment.isKum ? 4 : 0,
          );
    final tile = KumShake(
      enabled: comment.isKum,
      child: Padding(
      padding: outerPadding,
      child: Stack(
        children: [
          SkinCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkinHeader(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
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
                    if (!widget.compact)
                      _CommentFavButton(
                        comment: comment,
                        currentPage: widget.currentPage,
                      )
                    else if (widget.onDelete != null)
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(Icons.delete_outline, size: 24, color: cs.outline),
                      ),
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
                    if (widget.compact)
                      ClipRect(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: (MediaQuery.textScalerOf(context).scale(
                                  theme.textTheme.bodyMedium?.fontSize ?? 14,
                                ) * 1.45 * 5),
                          ),
                          child: CommentHtml(
                            comment.text!,
                            compact: true,
                            onSvalkoPost: (id) =>
                                Navigator.of(context).pushNamed('/post', arguments: id),
                          ),
                        ),
                      )
                    else
                      CommentHtml(
                      comment.text!,
                      onSvalkoPost: (id) =>
                          Navigator.of(context).pushNamed('/post', arguments: id),
                      ),
                    if (widget.compact)
                      for (final url in _extractVideoLinks(comment.text!))
                        if (VideoLinkCard.isSupported(url))
                          SelectionContainer.disabled(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: VideoLinkCard(url: url),
                            ),
                          ),
                  ],
                  for (final url in comment.imageUrls) ...[
                    const SizedBox(height: 6),
                    SelectionContainer.disabled(
                      child: GestureDetector(
                        onTap: () => showFullscreenImage(context, url),
                        onLongPress: () => showMediaSheet(context, url),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: widget.compact ? 260 : 360),
                          child: MediaImage(
                            key: ValueKey(url),
                            url: url,
                            fit: BoxFit.contain,
                            loadingWidget: const ShimmerPlaceholder(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (final url in comment.videoUrls) ...[
                    const SizedBox(height: 6),
                    SelectionContainer.disabled(
                      child: GestureDetector(
                        onLongPress: () => showMediaSheet(context, url, isVideo: true),
                        child: widget.compact
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 260),
                                child: VideoPlayerWidget(url: url),
                              )
                            : VideoPlayerWidget(url: url),
                      ),
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
    ));
    if (widget.onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: tile,
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _CommentFavButton extends ConsumerWidget {
  const _CommentFavButton({required this.comment, required this.currentPage});

  final Comment comment;
  final int currentPage;

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
      favoriteCommentsProvider.select((list) => list.any((f) => f.id == comment.id)),
    );
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final stripped = comment.text == null ? '' : _stripHtml(comment.text!);
        final preview = stripped.isEmpty
            ? null
            : stripped.substring(0, stripped.length > 120 ? 120 : stripped.length);
        ref.read(favoriteCommentsProvider.notifier).toggle(
              FavoriteComment(
                id: comment.id,
                postId: comment.postId,
                commentPage: currentPage,
                authorName: comment.author.name,
                authorProfileUrl: comment.author.profileUrl,
                publishedAt: comment.publishedAt,
                addedAt: DateTime.now(),
                previewText: preview,
                textHtml: comment.text,
                imageUrls: comment.imageUrls,
                videoUrls: comment.videoUrls,
                isKum: comment.isKum,
              ),
            );
      },
      child: Icon(
        isFav ? Icons.bookmark : Icons.bookmark_outline,
        size: 18,
        color: isFav ? cs.primary : cs.outline,
      ),
    );
  }
}
