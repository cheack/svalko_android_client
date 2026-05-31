import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';
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
  late final ScrollController _tagsScrollController;
  List<Tag>? _tags;
  String? _lastScrolledTag;

  @override
  void initState() {
    super.initState();
    final savedOffset = ref.read(drawerTagsScrollOffsetProvider);
    _tagsScrollController = ScrollController(initialScrollOffset: savedOffset);
    _tagsScrollController.addListener(() {
      ref.read(drawerTagsScrollOffsetProvider.notifier).state =
          _tagsScrollController.offset;
    });
  }

  @override
  void dispose() {
    _tagsScrollController.dispose();
    super.dispose();
  }

  void _scrollToTag(String? tag) {
    if (tag == null) {
      if (_tagsScrollController.hasClients) _tagsScrollController.jumpTo(0);
      return;
    }
    final tags = _tags;
    if (tags == null || !_tagsScrollController.hasClients) return;
    final index = tags.indexWhere((t) => t.name == tag);
    if (index < 0) return;
    const itemHeight = 40.0;
    final target = (index * itemHeight).clamp(
      0.0,
      _tagsScrollController.position.maxScrollExtent,
    );
    _tagsScrollController.jumpTo(target);
  }

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
        Navigator.of(context).pushNamed('/random-post', arguments: value);
      case Err(:final error):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final activeTag = ref.watch(activeTagProvider);
    final s = AppStrings.of(ref.watch(languageProvider));
    final theme = Theme.of(context);

    if (activeTag != _lastScrolledTag) {
      _lastScrolledTag = activeTag;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTag(activeTag));
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.primary,
            height: topPadding,
          ),
          Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(s.navHome),
              onTap: () {
                ref.read(activeTagProvider.notifier).state = null;
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
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
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.navImages),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/images');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Избранное'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/favorites');
              },
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
                data: (tags) {
                  _tags = tags;
                  return ListView.builder(
                    controller: _tagsScrollController,
                    padding: EdgeInsets.zero,
                    itemCount: tags.length,
                    itemBuilder: (ctx, i) {
                      final tag = tags[i];
                      final isActive = tag.name == activeTag;
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        selected: isActive,
                        title: Text(
                          '#${tag.name}',
                          style: isActive
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
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
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Настройки'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О приложении'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/about');
              },
            ),
            const Divider(height: 1),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/trends');
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
                child: Row(
                  children: [
                    CachedNetworkImage(
                      imageUrl: '${Config.baseUrl}/trends_images.php?informer=1',
                      width: 110,
                      height: 38,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox(width: 110, height: 38),
                    ),
                    const SizedBox(width: 4),
                    CachedNetworkImage(
                      imageUrl: '${Config.baseUrl}/trends_images.php?informer=1&mode=1',
                      width: 60,
                      height: 38,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox(width: 60, height: 38),
                    ),
                  ],
                ),
              ),
            ),
          ],
          )),
        ],
      ),
    );
  }
}
