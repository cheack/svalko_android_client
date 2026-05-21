import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config.dart';
import '../../../core/l10n.dart';
import '../../../core/settings_storage.dart';
import '../../../models/post.dart';
import '../../../ui/widgets/image_carousel.dart';
import '../../../ui/widgets/linked_text.dart';
import '../../../ui/widgets/post_tags.dart';
import '../../../ui/widgets/video_link_card.dart';
import '../../../ui/widgets/video_player_widget.dart';


class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(ref.watch(languageProvider));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showPostSheet(context, s, post.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + date above media
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Text(
                    post.author.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(post.publishedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty)
              ImageCarousel(urls: post.imageUrls),
            if (post.imageUrls.isEmpty && post.videoUrls.isNotEmpty)
              VideoPlayerWidget(url: post.videoUrls.first),
            for (final link in post.externalLinks)
              if (VideoLinkCard.isSupported(link))
                VideoLinkCard(url: link, onTap: onTap),
            if (post.text != null && post.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: LinkedText(
                  post.text!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 4,
                  onSvalkoPost: (id) => Navigator.of(context)
                      .pushNamed('/post', arguments: id),
                ),
              ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: PostTagsRow(tags: post.tags),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  if (post.rating != null) ...[
                    Icon(Icons.thumb_up_outlined,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 2),
                    Text('${post.rating!.plus}',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Icon(Icons.thumb_down_outlined,
                        size: 14, color: colorScheme.error),
                    const SizedBox(width: 2),
                    Text('${post.rating!.minus}',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.comment_outlined, size: 14),
                  const SizedBox(width: 2),
                  Text(s.commentsTooltip(post.commentCount),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';


  static Future<void> _showPostSheet(
      BuildContext context, AppStrings s, int id) async {
    final postUrl = '${Config.baseUrl}/$id.html';
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser_outlined),
              title: Text(s.openInBrowser),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final uri = Uri.parse(postUrl);
                if (!await launchUrl(uri,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.unknownError)),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(s.shareLink),
              onTap: () {
                Navigator.pop(sheetCtx);
                Share.share(postUrl);
              },
            ),
          ],
        ),
      ),
    );
  }
}
