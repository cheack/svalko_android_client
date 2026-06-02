import 'package:flutter/material.dart';

class SvalkoSkinExt extends ThemeExtension<SvalkoSkinExt> {
  const SvalkoSkinExt({this.cardPattern, this.headerColor, this.linkColor});

  final DecorationImage? cardPattern;
  final Color? headerColor;
  final Color? linkColor;

  @override
  SvalkoSkinExt copyWith({
    DecorationImage? cardPattern,
    Color? headerColor,
    Color? linkColor,
  }) =>
      SvalkoSkinExt(
        cardPattern: cardPattern ?? this.cardPattern,
        headerColor: headerColor ?? this.headerColor,
        linkColor: linkColor ?? this.linkColor,
      );

  @override
  SvalkoSkinExt lerp(ThemeExtension<SvalkoSkinExt>? other, double t) => this;
}

/// Wraps [child] in a [ColoredBox] using [SvalkoSkinExt.headerColor] when set.
/// Falls through transparently for skins that have no header color.
class SkinHeader extends StatelessWidget {
  const SkinHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<SvalkoSkinExt>()?.headerColor;
    if (color == null) return child;
    return ColoredBox(color: color, child: child);
  }
}
