import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/comment.dart';
import '../../../ui/widgets/image_viewer.dart';
import '../../../ui/widgets/linked_text.dart';
import '../../../ui/widgets/media_actions.dart';
import '../../../ui/widgets/shimmer_placeholder.dart';
import '../../../ui/widgets/video_player_widget.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  comment.author.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDate(comment.publishedAt),
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Text('#${comment.id}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          if (comment.text != null && comment.text!.isNotEmpty) ...[
            const SizedBox(height: 4),
            LinkedText(
              comment.text!,
              style: theme.textTheme.bodyMedium,
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
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  placeholder: (_, _) => const ShimmerPlaceholder(),
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
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
