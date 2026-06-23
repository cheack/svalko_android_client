import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

AppBar buildBlurAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget>? actions,
  Widget? leading,
  PreferredSizeWidget? bottom,
}) {
  final appBarColor = Theme.of(context).appBarTheme.backgroundColor ??
      Theme.of(context).colorScheme.surface;
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: ThemeData.estimateBrightnessForColor(appBarColor) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(color: appBarColor.withValues(alpha: 0.85)),
      ),
    ),
    title: title,
    actions: actions,
    leading: leading,
    bottom: bottom,
  );
}

/// Top padding for a scrollable body when [extendBodyBehindAppBar] is true.
/// Pass [bottomHeight] if the AppBar has a [bottom] widget (e.g. tab bar).
double blurAppBarTopPadding(BuildContext context, {double bottomHeight = 0}) =>
    MediaQuery.of(context).padding.top + kToolbarHeight + bottomHeight;

/// Horizontal padding that centres content up to [maxWidth] in wide viewports.
double landscapeHPadding(BuildContext context, {double maxWidth = 600}) {
  final w = MediaQuery.of(context).size.width;
  return w > maxWidth ? (w - maxWidth) / 2 : 0;
}
