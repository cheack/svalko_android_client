import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_storage.dart';
import '../../models/author.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/deletable_items.dart';
import '../../models/comment.dart';
import '../post/widgets/comment_tile.dart';
import '../navigation/app_drawer.dart';
import 'favorites_export.dart';
import 'favorites_storage.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Future<void> _export(
    BuildContext context,
    FavoritesNotifier postsNotifier,
    FavoriteCommentsNotifier commentsNotifier,
  ) async {
    final json = jsonEncode({
      'posts': postsNotifier.exportList(),
      'comments': commentsNotifier.exportList(),
    });
    await shareFavoritesJson(json);
  }

  Future<void> _import(
    BuildContext context,
    FavoritesNotifier postsNotifier,
    FavoriteCommentsNotifier commentsNotifier,
  ) async {
    final content = await pickFavoritesJsonFile();
    if (content == null) return;

    try {
      final decoded = jsonDecode(content);

      int addedPosts;
      int addedComments;
      if (decoded is List) {
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
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final postsNotifier = ref.read(favoritesProvider.notifier);
    final commentsNotifier = ref.read(favoriteCommentsProvider.notifier);
    final fontSize = ref.watch(fontSizeProvider);

    return DefaultTabController(
      length: 2,
      child: ScaffoldMessenger(
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
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
              padding: MediaQuery.of(context).padding.copyWith(
                top: blurAppBarTopPadding(context, bottomHeight: kTextTabBarHeight),
              ),
            ),
            child: TabBarView(
              children: [
                _PostsTab(favorites: favorites, notifier: postsNotifier),
                const _CommentsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.favorites, required this.notifier});

  final List<FavoritePost> favorites;
  final FavoritesNotifier notifier;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> with DeletableItems<_PostsTab> {

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (widget.favorites.isEmpty) {
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
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: landscapeHPadding(context),
          right: landscapeHPadding(context),
        ),
        itemCount: widget.favorites.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final fav = widget.favorites[index];
          final tile = ListTile(
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
              Navigator.of(context).pushNamed('/post', arguments: fav.id);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 26),
              color: Theme.of(context).colorScheme.outline,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerRight,
              onPressed: () => startDelete(
                context, fav.id, () => widget.notifier.add(fav),
              ),
            ),
          );

          return wrapAnimated(fav.id, tile, () => widget.notifier.remove(fav.id));
        },
      );
  }
}

// ---------------------------------------------------------------------------

class _CommentsTab extends ConsumerStatefulWidget {
  const _CommentsTab();

  @override
  ConsumerState<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<_CommentsTab>
    with DeletableItems<_CommentsTab> {

  Comment _commentFromFavorite(FavoriteComment fav) => Comment(
        id: fav.id,
        postId: fav.postId,
        author: Author(name: fav.authorName, profileUrl: fav.authorProfileUrl),
        publishedAt: fav.publishedAt,
        text: fav.textHtml ?? fav.previewText,
        imageUrls: fav.imageUrls,
        videoUrls: fav.videoUrls,
        isKum: fav.isKum,
      );

  @override
  Widget build(BuildContext context) {
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
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          left: landscapeHPadding(context),
          right: landscapeHPadding(context),
        ),
        itemCount: comments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final fav = comments[index];
          final tile = CommentTile(
            comment: _commentFromFavorite(fav),
            currentPage: fav.commentPage,
            compact: true,
            onDelete: () => startDelete(context, fav.id, () => notifier.add(fav)),
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.of(context).pushNamed(
                '/post',
                arguments: (fav.postId, fav.id, fav.commentPage),
              );
            },
          );

          return wrapAnimated(fav.id, tile, () => notifier.remove(fav.id));
        },
      );
  }
}

enum _MenuAction { export, import }
