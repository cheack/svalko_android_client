import 'package:flutter/material.dart';

class PageNavPanel extends StatelessWidget {
  const PageNavPanel({
    super.key,
    required this.currentPage,
    required this.maxPage,
    required this.canGoNewer,
    required this.canGoOlder,
    required this.isLoading,
    required this.onNewer,
    required this.onOlder,
    required this.onPageSelected,
  });

  final int currentPage;
  final int maxPage;
  final bool canGoNewer;
  final bool canGoOlder;
  final bool isLoading;
  final VoidCallback onNewer;
  final VoidCallback onOlder;
  final void Function(int) onPageSelected;

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      routeSettings: const RouteSettings(name: '/page-picker'),
      builder: (ctx) => _PagePickerSheet(
        currentPage: currentPage,
        maxPage: maxPage,
        onSelected: (page) {
          Navigator.pop(ctx);
          if (page != currentPage) onPageSelected(page);
        },
      ),
    );
  }

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : GestureDetector(
                      onTap: () => _showPicker(context),
                      child: Text(
                        'стр. $currentPage',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
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

class _PagePickerSheet extends StatefulWidget {
  const _PagePickerSheet({
    required this.currentPage,
    required this.maxPage,
    required this.onSelected,
  });

  final int currentPage;
  final int maxPage;
  final void Function(int) onSelected;

  @override
  State<_PagePickerSheet> createState() => _PagePickerSheetState();
}

class _PagePickerSheetState extends State<_PagePickerSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentPage.toDouble();
  }

  void _adjust(int delta) => setState(() {
        _value = (_value + delta).clamp(0.0, widget.maxPage.toDouble());
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _value.round();

    return SafeArea(
      child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('стр. $page', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _StepButton(label: '−5', onTap: () => _adjust(-5)),
                _StepButton(label: '−1', onTap: () => _adjust(-1)),
                Expanded(
                  child: Slider(
                    value: _value,
                    min: 0,
                    max: widget.maxPage.toDouble(),
                    divisions: widget.maxPage > 0 ? widget.maxPage : null,
                    onChanged: (v) => setState(() => _value = v),
                  ),
                ),
                _StepButton(label: '+1', onTap: () => _adjust(1)),
                _StepButton(label: '+5', onTap: () => _adjust(5)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => widget.onSelected(page),
              child: const Text('Перейти'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
