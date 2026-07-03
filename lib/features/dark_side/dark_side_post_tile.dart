import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/open_url.dart';
import '../../models/dark_side_post.dart';
import '../../ui/widgets/image_carousel.dart';
import '../../ui/widgets/post_action_buttons.dart';
import '../../ui/widgets/post_header.dart' show PostHeader;

class DarkSidePostTile extends StatelessWidget {
  const DarkSidePostTile({super.key, required this.post});

  final DarkSidePost post;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DarkSideHeader(
            author: post.author.isEmpty ? 'Аноним' : post.author,
            publishedAt: post.publishedAt,
            authorPostCount: post.authorPostCount,
          ),
          if (post.imageUrls.isNotEmpty)
            SelectionContainer.disabled(
              child: ImageCarousel(urls: post.imageUrls, maxHeight: 400),
            ),
          if (post.hasText)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _DarkSideRichText(parts: post.textParts),
            ),
          if (post.approverComment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _DarkSideRichText(
                parts: [
                  if (post.approvedBy != null) DarkSideText('${post.approvedBy}: '),
                  ...post.approverCommentParts,
                ],
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          SelectionContainer.disabled(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
              child: Row(
                children: [
                  DarkSidePostFavButton(post: post, iconSize: 18, visualDensity: VisualDensity.compact),
                  PostShareButton(postId: post.id, iconSize: 18, visualDensity: VisualDensity.compact),
                ],
              ),
            ),
          ),
        ],
      );
}

class _DarkSideHeader extends StatelessWidget {
  const _DarkSideHeader({
    required this.author,
    required this.publishedAt,
    this.authorPostCount,
  });

  final String author;
  final DateTime publishedAt;
  final int? authorPostCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  author,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  PostHeader.formatRelativeTime(publishedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (authorPostCount != null) ...[
            const SizedBox(width: 8),
            Text(
              'Всего постов: $authorPostCount',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkSideRichText extends StatefulWidget {
  const _DarkSideRichText({required this.parts, this.style});

  final List<DarkSideTextPart> parts;
  final TextStyle? style;

  @override
  State<_DarkSideRichText> createState() => _DarkSideRichTextState();
}

class _DarkSideRichTextState extends State<_DarkSideRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final theme = Theme.of(context);
    final linkColor = theme.colorScheme.primary;
    return Text.rich(
      TextSpan(
        style: widget.style ?? theme.textTheme.bodyMedium,
        children: [
          for (final part in widget.parts)
            switch (part) {
              DarkSideText(:final text) => TextSpan(text: text),
              DarkSideLink(:final label, :final url) => TextSpan(
                  text: label,
                  style: TextStyle(color: linkColor, decoration: TextDecoration.underline),
                  recognizer: _recognizerFor(context, url),
                ),
            },
        ],
      ),
    );
  }

  TapGestureRecognizer _recognizerFor(BuildContext context, String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => openInBrowser(context, url);
    _recognizers.add(recognizer);
    return recognizer;
  }
}
