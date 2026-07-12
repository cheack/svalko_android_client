import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/search_result.dart';
import 'search_controller.dart';

Future<SearchParams?> showSearchDialog(BuildContext context, WidgetRef ref) {
  return showDialog<SearchParams>(
    context: context,
    routeSettings: const RouteSettings(name: '/search'),
    builder: (_) => _SearchDialog(initial: ref.read(lastSearchParamsProvider)),
  );
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({this.initial});

  final SearchParams? initial;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _queryController;
  late String _order;
  late bool _searchComments;

  @override
  void initState() {
    super.initState();
    _queryController =
        TextEditingController(text: widget.initial?.query ?? '');
    _order = widget.initial?.order ?? 'rel';
    _searchComments = widget.initial?.searchComments ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queryController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _queryController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    Navigator.of(context).pop(SearchParams(
      query: query,
      order: _order,
      searchComments: _searchComments,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Поиск'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _queryController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Поисковый запрос',
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          Text(
            'Можно искать по ссылке на пост или по его айди',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('Сортировка', style: theme.textTheme.labelMedium),
          RadioGroup<String>(
            groupValue: _order,
            onChanged: (v) => setState(() => _order = v ?? _order),
            child: Column(
              children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('По релевантности'),
                  value: 'rel',
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('По дате'),
                  value: 'date',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Искать в комментариях'),
            value: _searchComments,
            onChanged: (v) => setState(() => _searchComments = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Найти'),
        ),
      ],
    );
  }
}
