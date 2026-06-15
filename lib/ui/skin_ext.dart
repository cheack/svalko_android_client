import 'package:flutter/material.dart';

class SvalkoSkinExt extends ThemeExtension<SvalkoSkinExt> {
  const SvalkoSkinExt({
    this.cardPattern,
    this.headerColor,
    this.linkColor,
    this.cardDividers = false,
  });

  final DecorationImage? cardPattern;
  final Color? headerColor;
  final Color? linkColor;
  /// When true, feed cards have no border/shadow — items are separated by a divider line.
  final bool cardDividers;

  @override
  SvalkoSkinExt copyWith({
    DecorationImage? cardPattern,
    Color? headerColor,
    Color? linkColor,
    bool? cardDividers,
  }) =>
      SvalkoSkinExt(
        cardPattern: cardPattern ?? this.cardPattern,
        headerColor: headerColor ?? this.headerColor,
        linkColor: linkColor ?? this.linkColor,
        cardDividers: cardDividers ?? this.cardDividers,
      );

  @override
  SvalkoSkinExt lerp(ThemeExtension<SvalkoSkinExt>? other, double t) => this;
}

/// Card container that applies the skin decoration (background color, pattern,
/// border or divider-mode styling) from [SvalkoSkinExt].
class SkinCard extends StatelessWidget {
  const SkinCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skinExt = theme.extension<SvalkoSkinExt>();
    final dividers = skinExt?.cardDividers ?? false;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        image: skinExt?.cardPattern,
        borderRadius: dividers ? null : BorderRadius.circular(4),
        border: dividers ? null : Border.all(color: cs.outline, width: 1),
      ),
      child: child,
    );
  }
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
    return SizedBox(width: double.infinity, child: ColoredBox(color: color, child: child));
  }
}
