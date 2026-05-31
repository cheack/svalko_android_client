import 'package:flutter/material.dart';
import '../../models/post.dart';

class PostHeader extends StatefulWidget {
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
    final buf = StringBuffer('+${r.plus} | ${r.neutral} | ${r.minus} = ${r.percentage}%');
    if (borodaCount != null && borodaCount > 0) buf.write(' · б:$borodaCount');
    return buf.toString();
  }

  static String formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  final _ratingKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  void _dismiss() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showRatingPopup() {
    final r = widget.rating;
    if (r == null) return;
    _dismiss();

    final box = _ratingKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenWidth = MediaQuery.of(context).size.width;

    _overlay = OverlayEntry(builder: (ctx) {
      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismiss(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 4,
            right: screenWidth - offset.dx - size.width,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ЗАЧОТ: +${r.plus}'),
                      Text('? я чото п: ${r.neutral}'),
                      Text('КГ/АМ: ${r.minus}'),
                      const Divider(height: 10),
                      Text('ИТОГО: ${r.percentage}%'),
                      if (widget.borodaCount != null && widget.borodaCount! > 0)
                        Text('Бород: ${widget.borodaCount}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          GestureDetector(
            onTap: widget.onAuthorTap,
            child: Text(
              widget.author,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            PostHeader.formatDate(widget.publishedAt),
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (widget.rating != null)
            GestureDetector(
              key: _ratingKey,
              onTap: _showRatingPopup,
              child: Text(
                PostHeader.formatRating(widget.rating!, widget.borodaCount),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }
}
