import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'favorites_storage.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final notifier = ref.read(favoritesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
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
                        if (fav.previewText != null && fav.previewText!.isNotEmpty)
                          Text(
                            fav.previewText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    isThreeLine: fav.previewText != null && fav.previewText!.isNotEmpty,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/post', arguments: fav.id),
                  ),
                );
              },
            ),
    );
  }
}
