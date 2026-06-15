import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_storage.dart';

/// Applies the user's font-size preference to [child] via [MediaQuery].
class FontScaledBody extends ConsumerWidget {
  const FontScaledBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
      ),
      child: child,
    );
  }
}
