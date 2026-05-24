import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'favorites_storage.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _export(BuildContext context, FavoritesNotifier notifier) async {
    final json = notifier.exportJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/svalko_favorites.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Избранное Свалочки',
    );
  }

  Future<void> _import(BuildContext context, FavoritesNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    try {
      final content = await File(result.files.single.path!).readAsString();
      final added = notifier.importJson(content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(added == 0
                ? 'Новых постов не найдено'
                : 'Добавлено: $added'),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final notifier = ref.read(favoritesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: [
          PopupMenuButton<_MenuAction>(
            onSelected: (action) {
              switch (action) {
                case _MenuAction.export:
                  _export(context, notifier);
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
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Нет избранных постов',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final fav = favorites[index];
                return Dismissible(
                  key: ValueKey(fav.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: Colors.red,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => notifier.remove(fav.id),
                  child: ListTile(
                    leading: fav.firstImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: fav.firstImageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox(
                                width: 56,
                                height: 56,
                              ),
                            ),
                          )
                        : null,
                    title: Text(
                      fav.authorName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fmt(fav.publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (fav.previewText != null &&
                            fav.previewText!.isNotEmpty)
                          Text(
                            fav.previewText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    isThreeLine: fav.previewText != null &&
                        fav.previewText!.isNotEmpty,
                    onTap: () => Navigator.of(context)
                        .pushNamed('/post', arguments: fav.id),
                  ),
                );
              },
            ),
    );
  }
}

enum _MenuAction { export, import }
