import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/settings_storage.dart';
import '../../models/author.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../models/comment.dart';
import '../post/widgets/comment_tile.dart';
import '../navigation/app_drawer.dart';
import 'favorites_storage.dart';

mixin _DeletableItems<T extends StatefulWidget> on State<T> {
  final _deleting = <int>{};
  final _growing = <int>{};

  void startDelete(BuildContext context, int id, VoidCallback onRestore) {
    setState(() => _deleting.add(id));
    _showUndoSnackBar(context, () {
      if (_deleting.contains(id)) {
        setState(() => _deleting.remove(id));
      } else {
        setState(() => _growing.add(id));
        onRestore();
      }
    });
  }

  Widget wrapAnimated(int id, Widget child, VoidCallback onRemove) {
    if (_deleting.contains(id)) {
      return _AnimatedItem(
        key: ValueKey(id),
        shrink: true,
        onEnd: () {
          onRemove();
          setState(() => _deleting.remove(id));
        },
        child: child,
      );
    }
    if (_growing.contains(id)) {
      return _AnimatedItem(
        key: ValueKey(id),
        shrink: false,
        onEnd: () => setState(() => _growing.remove(id)),
        child: child,
      );
    }
    return KeyedSubtree(key: ValueKey(id), child: child);
  }
}

void _showUndoSnackBar(BuildContext context, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  Timer? timer;
  final ctrl = messenger.showSnackBar(SnackBar(
    duration: const Duration(days: 1),
    content: const Text('Удалено из избранного'),
    action: SnackBarAction(
      label: 'Отменить',
      onPressed: () {
        timer?.cancel();
        onUndo();
      },
    ),
  ));
  timer = Timer(const Duration(seconds: 5), ctrl.close);
  ctrl.closed.then((_) => timer?.cancel());
}

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

class _PostsTabState extends State<_PostsTab> with _DeletableItems<_PostsTab> {

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
    with _DeletableItems<_CommentsTab> {

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

// ---------------------------------------------------------------------------

class _AnimatedItem extends StatefulWidget {
  const _AnimatedItem({
    super.key,
    required this.child,
    required this.shrink,
    required this.onEnd,
  });

  final Widget child;
  final bool shrink;
  final VoidCallback onEnd;

  @override
  State<_AnimatedItem> createState() => _AnimatedItemState();
}

class _AnimatedItemState extends State<_AnimatedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ctrl.forward().then((_) {
      if (mounted) widget.onEnd();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    final size = widget.shrink
        ? Tween<double>(begin: 1, end: 0).animate(curved)
        : Tween<double>(begin: 0, end: 1).animate(curved);
    final opacity = widget.shrink
        ? Tween<double>(begin: 1, end: 0).animate(curved)
        : Tween<double>(begin: 0, end: 1).animate(curved);
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: size,
        child: FadeTransition(opacity: opacity, child: widget.child),
      ),
    );
  }
}
