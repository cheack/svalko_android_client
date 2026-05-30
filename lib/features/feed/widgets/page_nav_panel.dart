import 'package:flutter/material.dart';

class PageNavPanel extends StatelessWidget {
  const PageNavPanel({
    super.key,
    required this.currentPage,
    required this.canGoNewer,
    required this.canGoOlder,
    required this.isLoading,
    required this.onNewer,
    required this.onOlder,
  });

  final int currentPage;
  final bool canGoNewer;
  final bool canGoOlder;
  final bool isLoading;
  final VoidCallback onNewer;
  final VoidCallback onOlder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: 'Новее',
              visualDensity: VisualDensity.compact,
              onPressed: (!isLoading && canGoNewer) ? onNewer : null,
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'стр. $currentPage',
                        style: theme.textTheme.bodyMedium,
                      ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18),
              tooltip: 'Старее',
              visualDensity: VisualDensity.compact,
              onPressed: (!isLoading && canGoOlder) ? onOlder : null,
            ),
          ],
        ),
      ),
    );
  }
}
