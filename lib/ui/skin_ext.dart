import 'package:flutter/material.dart';

class SvalkoSkinExt extends ThemeExtension<SvalkoSkinExt> {
  const SvalkoSkinExt({this.cardPattern});

  final DecorationImage? cardPattern;

  @override
  SvalkoSkinExt copyWith({DecorationImage? cardPattern}) =>
      SvalkoSkinExt(cardPattern: cardPattern ?? this.cardPattern);

  @override
  SvalkoSkinExt lerp(ThemeExtension<SvalkoSkinExt>? other, double t) => this;
}
