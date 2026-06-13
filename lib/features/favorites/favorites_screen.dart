import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../navigation/app_drawer.dart';
import 'favorites_storage.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _export(
    BuildContext context,
    FavoritesNotifier postsNotifier,
    FavoriteCommentsNotifier commentsNotifier,
  ) async {
    final json = jsonEncode({
      'posts': postsNotifier.exportList(),
      'comments': commentsNotifier.exportList(),
    });
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/svalko_favorites.json');
    await file.writeAsString(json);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'Избранное Свалочки');
  }

  Future<void> _import(
    BuildContext context,
    FavoritesNotifier postsNotifier,
    FavoriteCommentsNotifier commentsNotifier,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    try {
      final content = await File(result.files.single.path!).readAsString();
      final decoded = jsonDecode(content);

      int addedPosts;
      int addedComments;
      if (decoded is List) {
        // Legacy format: flat array of posts
        addedPosts = postsNotifier.importList(decoded);
        addedComments = 0;
      } else {
        final map = decoded as Map<String, dynamic>;
        addedPosts = postsNotifier.importList(
          (map['posts'] as List<dynamic>? ?? []),
        );
        addedComments = commentsNotifier.importList(
          (map['comments'] as List<dynamic>? ?? []),
        );
      }

      if (context.mounted) {
        final total = addedPosts + addedComments;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              total == 0
                  ? 'Новых записей не найдено'
                  : 'Добавлено: $addedPosts постов, $addedComments комментариев',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final postsNotifier = ref.read(favoritesProvider.notifier);
    final commentsNotifier = ref.read(favoriteCommentsProvider.notifier);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const AppDrawer(activePage: 'favorites'),
        drawerEdgeDragWidth: 80,
        appBar: AppBar(
          title: const Text('Избранное'),
          actions: [
            PopupMenuButton<_MenuAction>(
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.export:
                    _export(context, postsNotifier, commentsNotifier);
                  case _MenuAction.import:
                    _import(context, postsNotifier, commentsNotifier);
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: Builder(
              builder: (ctx) {
                final fg =
                    Theme.of(ctx).appBarTheme.foregroundColor ?? Colors.white;
                return TabBar(
                  labelColor: fg,
                  unselectedLabelColor: fg.withAlpha(178),
                  indicatorColor: fg,
                  tabs: const [
                    Tab(text: 'Посты'),
                    Tab(text: 'Комментарии'),
                  ],
                );
              },
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _PostsTab(favorites: favorites, notifier: postsNotifier),
            const _CommentsTab(),
          ],
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({required this.favorites, required this.notifier});

  final List<FavoritePost> favorites;
  final FavoritesNotifier notifier;

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Нет избранных постов', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
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
                      errorWidget: (_, _, _) =>
                          const SizedBox(width: 56, height: 56),
                    ),
                  )
                : null,
            title: Text(
              fav.authorName,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                if (fav.previewText != null && fav.previewText!.isNotEmpty)
                  Text(
                    fav.previewText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
              ],
            ),
            isThreeLine: fav.previewText != null && fav.previewText!.isNotEmpty,
            onTap: () =>
                Navigator.of(context).pushNamed('/post', arguments: fav.id),
          ),
        );
      },
    );
  }
}

class _CommentsTab extends ConsumerWidget {
  const _CommentsTab();

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(favoriteCommentsProvider);
    final notifier = ref.read(favoriteCommentsProvider.notifier);

    if (comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Нет избранных комментариев',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: comments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fav = comments[index];
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
            title: Text(
              fav.authorName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _fmt(fav.publishedAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Пост #${fav.postId} · стр. ${fav.commentPage}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                if (fav.previewText != null && fav.previewText!.isNotEmpty)
                  Text(
                    fav.previewText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
              ],
            ),
            isThreeLine: fav.previewText != null && fav.previewText!.isNotEmpty,
            onTap: () => Navigator.of(context).pushNamed(
              '/post',
              arguments: (fav.postId, fav.id, fav.commentPage),
            ),
          ),
        );
      },
    );
  }
}

enum _MenuAction { export, import }
