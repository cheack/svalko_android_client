import 'package:flutter/material.dart';

/// Renders `<marquee>` text the way old browsers did: the text starts fully
/// off-screen on the right, scrolls across, exits fully off-screen on the
/// left, then restarts from the right.
class HtmlMarquee extends StatefulWidget {
  const HtmlMarquee(this.text, {super.key, this.style, this.reverse = false});

  final String text;
  final TextStyle? style;

  /// True for `direction="right"` (enters from the left, exits on the
  /// right — the opposite of the classic marquee default).
  final bool reverse;

  @override
  State<HtmlMarquee> createState() => _HtmlMarqueeState();
}

// Roughly matches the classic <marquee> default speed (scrollamount=6,
// scrolldelay~85ms).
const double _kPixelsPerSecond = 90;

class _HtmlMarqueeState extends State<HtmlMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _lastTotalDistance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(HtmlMarquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.style != widget.style ||
        old.reverse != widget.reverse) {
      _lastTotalDistance = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restart(double totalDistance) {
    if (!mounted || totalDistance <= 0) return;
    _controller
      ..duration = Duration(
          milliseconds: (totalDistance / _kPixelsPerSecond * 1000).round())
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // A small buffer so the text is guaranteed to fully clear the left edge
    // before the loop restarts, even with rounding/kerning differences
    // between this measurement and the actual rendered Text widget.
    final textWidth = painter.width + 4;
    final textHeight = painter.height;

    return ClipRect(
      child: SizedBox(
        height: textHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : textWidth;
            final totalDistance = containerWidth + textWidth;
            if (_lastTotalDistance != totalDistance) {
              _lastTotalDistance = totalDistance;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _restart(totalDistance));
            }
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                final dx = widget.reverse
                    ? -textWidth + progress * totalDistance
                    : containerWidth - progress * totalDistance;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: dx,
                      top: 0,
                      child: Text(
                        widget.text,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
