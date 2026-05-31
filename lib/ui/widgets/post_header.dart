import 'package:flutter/material.dart';
import '../../models/post.dart';

class PostHeader extends StatelessWidget {
  const PostHeader({
    super.key,
    required this.author,
    required this.publishedAt,
    this.rating,
    this.borodaCount,
    this.onAuthorTap,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
  });

  final String author;
  final DateTime publishedAt;
  final PostRating? rating;
  final int? borodaCount;
  final VoidCallback? onAuthorTap;
  final EdgeInsetsGeometry padding;

  static String formatRating(PostRating r, int? borodaCount) {
    final buf = StringBuffer('+${r.plus} | ${r.minus} = ${r.percentage}%');
    if (borodaCount != null && borodaCount > 0) buf.write(' · б:$borodaCount');
    return buf.toString();
  }

  static String formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: Text(
              author,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDate(publishedAt),
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (rating != null)
            Text(
              formatRating(rating!, borodaCount),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
        ],
      ),
    );
  }
}
