import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_storage.dart';
import '../../features/favorites/favorites_export.dart';
import '../../features/favorites/favorites_storage.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/deletable_items.dart';
import '../navigation/app_drawer.dart';

enum _MenuAction { export, import }

class DarkSideFavoritesScreen extends ConsumerStatefulWidget {
  const DarkSideFavoritesScreen({super.key});

  @override
  ConsumerState<DarkSideFavoritesScreen> createState() =>
      _DarkSideFavoritesScreenState();
}

class _DarkSideFavoritesScreenState extends ConsumerState<DarkSideFavoritesScreen>
    with DeletableItems<DarkSideFavoritesScreen> {
  static String _fmt(DateTime? dt) {
    if (dt == null) return 'дата неизвестна';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _export(DarkSideFavoritesNotifier notifier) async {
    await shareFavoritesJson(notifier.exportJson());
  }

  Future<void> _import(BuildContext context, DarkSideFavoritesNotifier notifier) async {
    final content = await pickFavoritesJsonFile();
    if (content == null) return;

    try {
      final added = notifier.importJson(content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added == 0 ? 'Новых записей не найдено' : 'Добавлено: $added постов',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(darkSideFavoritesProvider);
    final notifier = ref.read(darkSideFavoritesProvider.notifier);
    final fontSize = ref.watch(fontSizeProvider);

    return ScaffoldMessenger(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: const AppDrawer(activePage: 'favorites'),
        drawerEdgeDragWidth: 80,
        appBar: buildBlurAppBar(
          context,
          title: const Text('Избранное'),
          actions: [
            PopupMenuButton<_MenuAction>(
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.export:
                    _export(notifier);
                  case _MenuAction.import:
                    _import(context, notifier);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _MenuAction.export,
                  child: ListTile(
                    leading: Icon(Icons.upload_outlined),
                    title: Text('Экспорт'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _MenuAction.import,
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Импорт'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
          ),
          child: favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Нет избранных постов', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(
                    top: blurAppBarTopPadding(context),
                    left: landscapeHPadding(context),
                    right: landscapeHPadding(context),
                  ),
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final fav = favorites[index];
                    final tile = ListTile(
                      leading: fav.firstImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: fav.firstImageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const SizedBox(width: 56, height: 56),
                              ),
                            )
                          : null,
                      title: Text(
                        fav.authorName.isEmpty ? 'Аноним' : fav.authorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(fav.publishedAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
                          ),
                          if (fav.previewText != null && fav.previewText!.isNotEmpty)
                            Text(
                              fav.previewText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
                            ),
                        ],
                      ),
                      isThreeLine: fav.previewText != null && fav.previewText!.isNotEmpty,
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.of(context).pushNamed('/dark-side-post', arguments: fav.id);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 26),
                        color: Theme.of(context).colorScheme.outline,
                        padding: EdgeInsets.zero,
                        onPressed: () => startDelete(
                          context, fav.id, () => notifier.add(fav),
                        ),
                      ),
                    );

                    return wrapAnimated(fav.id, tile, () => notifier.remove(fav.id));
                  },
                ),
        ),
      ),
    );
  }
}
