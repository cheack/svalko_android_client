import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/tag.dart';

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final result = await ref.watch(repositoryProvider).getTags();
  return switch (result) {
    Ok(:final value) => value,
    Err() => [],
  };
});

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _loadingRandom = false;

  Future<void> _openRandom() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    final result =
        await ref.read(repositoryProvider).getRandomPostId();
    if (!mounted) return;
    setState(() => _loadingRandom = false);
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop();
        Navigator.of(context).pushNamed('/post', arguments: value);
      case Err(:final error):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final s = AppStrings.of(ref.watch(languageProvider));
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(s.navHome),
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            ListTile(
              leading: _loadingRandom
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shuffle_outlined),
              title: Text(s.navRandom),
              onTap: _openRandom,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                s.navTags,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: tagsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('Ошибка загрузки')),
                data: (tags) => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tags.length,
                  itemBuilder: (ctx, i) {
                    final tag = tags[i];
                    return ListTile(
                      dense: true,
                      title: Text('#${tag.name}'),
                      trailing: tag.count != null
                          ? Text(
                              '${tag.count}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context)
                            .pushNamed('/tag', arguments: tag);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
