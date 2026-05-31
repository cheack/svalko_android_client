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

  static String formatExactDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _pluralize(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return few;
    return many;
  }

  static String formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) {
      final m = diff.inMinutes;
      return '$m ${_pluralize(m, 'минуту', 'минуты', 'минут')} назад';
    }
    if (diff.inDays < 1) {
      final h = diff.inHours;
      return '$h ${_pluralize(h, 'час', 'часа', 'часов')} назад';
    }
    if (diff.inDays < 30) {
      final d = diff.inDays;
      return '$d ${_pluralize(d, 'день', 'дня', 'дней')} назад';
    }
    final months = diff.inDays ~/ 30;
    if (months < 12) {
      return '$months ${_pluralize(months, 'месяц', 'месяца', 'месяцев')} назад';
    }
    final years = months ~/ 12;
    return '$years ${_pluralize(years, 'год', 'года', 'лет')} назад';
  }

  @override
  State<PostHeader> createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  final _ratingKey = GlobalKey();
  final _dateKey = GlobalKey();
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

  void _showPopup(GlobalKey anchorKey, Widget content) {
    _dismiss();
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenWidth = MediaQuery.of(context).size.width;

    final bool anchorLeft = offset.dx < screenWidth / 2;
    final double edgeMargin = 8;

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
            left: anchorLeft
                ? offset.dx.clamp(edgeMargin, screenWidth - edgeMargin)
                : null,
            right: anchorLeft
                ? null
                : (screenWidth - offset.dx - size.width)
                    .clamp(edgeMargin, screenWidth - edgeMargin),
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
                    child: content,
                  ),
                ),
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_overlay!);
  }

  void _showRatingPopup() {
    final r = widget.rating;
    if (r == null) return;
    _showPopup(
      _ratingKey,
      Column(
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
    );
  }

  void _showDatePopup() {
    _showPopup(
      _dateKey,
      Text(PostHeader.formatExactDate(widget.publishedAt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxAuthorWidth = constraints.maxWidth * 0.75;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxAuthorWidth),
                    child: GestureDetector(
                      onTap: widget.onAuthorTap,
                      child: Text(
                        widget.author,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: _dateKey,
                    onTap: _showDatePopup,
                    child: Text(
                      PostHeader.formatRelativeTime(widget.publishedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.rating != null)
                GestureDetector(
                  key: _ratingKey,
                  onTap: _showRatingPopup,
                  child: Text(
                    PostHeader.formatRating(widget.rating!, widget.borodaCount),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
