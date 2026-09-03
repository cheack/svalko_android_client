import 'package:flutter/material.dart';

import '../../core/open_url.dart';

/// Shown in place of an image that failed to load — makes the broken link
/// visible (and openable) instead of just leaving an empty gap.
class BrokenImagePlaceholder extends StatelessWidget {
  const BrokenImagePlaceholder({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      child: InkWell(
        onTap: () => openInBrowser(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: colors.error, size: 32),
              const SizedBox(height: 6),
              Text(
                'Картинка недоступна',
                style: TextStyle(color: colors.error, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                url,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
