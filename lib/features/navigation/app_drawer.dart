import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../features/feed/feed_controller.dart';
import '../../features/last/last_controller.dart';
import '../../features/navigation/tags_cache.dart';
import '../../models/tag.dart';
import '../../ui/widgets/inline_spinner.dart';
import '../../ui/widgets/new_post_sheet.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, this.activePage});

  final String? activePage;

  static const fojjerBase = 'НАОРАТЬ НА ФОЖЖЕРА';
  static const fojjerSuffixes = ['??', '?', '!', '!!11', '??!', '?!'];
  static const fojjerPrefixes = ['ФОЖЖЖЖЖЕЕР!!! ', '8-[  =  ] !!! '];

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _loadingRandom = false;
  late final ScrollController _tagsScrollController;
  List<Tag>? _tags;
  String? _lastScrolledTag;
  late String _fojjerText;
  bool _fojjerLoading = false;

  @override
  void initState() {
    super.initState();
    final savedOffset = ref.read(drawerTagsScrollOffsetProvider);
    _tagsScrollController = ScrollController(initialScrollOffset: savedOffset);
    _tagsScrollController.addListener(() {
      ref.read(drawerTagsScrollOffsetProvider.notifier).state =
          _tagsScrollController.offset;
    });
    final rng = Random();
    _fojjerText = AppDrawer.fojjerBase + AppDrawer.fojjerSuffixes[rng.nextInt(AppDrawer.fojjerSuffixes.length)];
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

  void _navTo(String page, void Function() action) {
    if (widget.activePage == page) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).popUntil((r) => r.isFirst);
    action();
  }

  Future<void> _shoutFojjer() async {
    if (_fojjerLoading) return;
    setState(() => _fojjerLoading = true);
    final result = await ref.read(apiProvider).fojjer();
    if (!mounted) return;
    final rng = Random();
    setState(() {
      _fojjerLoading = false;
      switch (result) {
        case Ok(:final value):
          _fojjerText = AppDrawer.fojjerPrefixes[rng.nextInt(AppDrawer.fojjerPrefixes.length)] + value;
        case Err():
          _fojjerText = AppDrawer.fojjerBase + AppDrawer.fojjerSuffixes[rng.nextInt(AppDrawer.fojjerSuffixes.length)];
      }
    });
  }

  void _showTagsDialog(BuildContext context, AppStrings s, List<Tag> tags, String? activeTag) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.navTags),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: tags.length,
            itemBuilder: (_, i) {
              final tag = tags[i];
              final isActive = tag.name == activeTag;
              return ListTile(
                dense: true,
                selected: isActive,
                title: Text(
                  '#${tag.name}',
                  style: isActive ? const TextStyle(fontWeight: FontWeight.bold) : null,
                ),
                trailing: tag.count != null
                    ? Text('${tag.count}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ))
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // close drawer
                  Navigator.of(context).pushNamed('/tag', arguments: tag);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRandom() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    await navigateToRandomPost(ref, context, (id) {
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed('/random-post', arguments: id);
    });
    if (mounted) setState(() => _loadingRandom = false);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsCacheProvider);
    final activeTag = ref.watch(activeTagProvider);
    final s = AppStrings.of(ref.watch(languageProvider));
    final theme = Theme.of(context);
    final isDarkSide = ref.watch(siteModeProvider) == SiteMode.darkSide;

    if (activeTag != _lastScrolledTag) {
      _lastScrolledTag = activeTag;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTag(activeTag));
    }

    final topPadding = MediaQuery.of(context).padding.top;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bottomItems = [
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
      if (!isDarkSide)
        ListTile(
          leading: _fojjerLoading
              ? const InlineSpinner()
              : const Icon(Icons.campaign_outlined),
          title: Text(_fojjerText),
          onTap: _shoutFojjer,
        ),
      if (!isDarkSide) const Divider(height: 1),
      if (!isDarkSide)
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed('/trends');
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
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
    ];

    final topNavItems = <Widget>[
      ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Text(s.navHome),
        selected: widget.activePage == 'home',
        onTap: () {
          ref.read(activeTagProvider.notifier).state = null;
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      if (!isDarkSide)
        ListTile(
          leading: const Icon(Icons.history_outlined),
          title: const Text('Ласты'),
          selected: widget.activePage == 'last',
          onTap: () => _navTo('last', () {
            ref.read(lastProvider.notifier).resetToFirst();
            Navigator.of(context).pushNamed('/last');
          }),
        ),
      if (!isDarkSide)
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Написать!'),
          onTap: () async {
            Navigator.of(context).pop();
            final api = ref.read(apiProvider);
            final settingsBox = ref.read(settingsBoxProvider);
            if (!context.mounted) return;
            final sent = await showNewPostSheet(context, api, settingsBox);
            if (sent && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Пост отправлен')),
              );
            }
          },
        ),
      ListTile(
        leading: _loadingRandom
            ? const InlineSpinner()
            : const Icon(Icons.shuffle_outlined),
        title: Text(s.navRandom),
        onTap: _openRandom,
      ),
      if (!isDarkSide)
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(s.navImages),
          selected: widget.activePage == 'images',
          onTap: () => _navTo('images', () => Navigator.of(context).pushNamed('/images')),
        ),
      if (!isDarkSide)
        ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('Избранное'),
          selected: widget.activePage == 'favorites',
          onTap: () => _navTo('favorites', () => Navigator.of(context).pushNamed('/favorites')),
        ),
    ];

    return Drawer(
      child: LayoutBuilder(builder: (context, constraints) {
        final topBar = Container(
          color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
          height: topPadding,
        );

        // Portrait: enough room to show all fixed items + tags list.
        if (constraints.maxHeight >= 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topBar,
              ...topNavItems,
              const Divider(height: 1),
              if (!isDarkSide)
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
              if (isDarkSide)
                const Spacer()
              else
              Expanded(
                child: tagsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                            Navigator.of(context).pushNamed('/tag', arguments: tag);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              ...bottomItems,
            ],
          );
        }

        // Landscape: all items in one scrollable list, tags collapsed.
        final tagsTile = tagsAsync.when(
          loading: () => ListTile(leading: const InlineSpinner(), title: Text(s.navTags)),
          error: (_, _) => ListTile(leading: const Icon(Icons.label_outline), title: Text(s.navTags)),
          data: (tags) {
            _tags = tags;
            return ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(s.navTags),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTagsDialog(context, s, tags, activeTag),
            );
          },
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topBar,
              ...topNavItems,
              const Divider(height: 1),
              if (!isDarkSide) tagsTile,
              ...bottomItems,
            ],
          ),
        );
      }),
    );
  }
}
