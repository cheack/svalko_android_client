import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/config.dart';
import '../../features/favorites/favorites_storage.dart';
import '../../models/dark_side_post.dart';
import '../../models/post.dart';

class PostShareButton extends StatelessWidget {
  const PostShareButton({super.key, required this.postId, this.iconSize, this.visualDensity});
  final int postId;
  final double? iconSize;
  final VisualDensity? visualDensity;

  static String postUrl(int id) => '${Config.baseUrl}/$id.html';

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share_outlined),
      iconSize: iconSize ?? 24,
      visualDensity: visualDensity,
      tooltip: 'Поделиться',
      onPressed: () => Share.share(postUrl(postId)),
    );
  }
}

class PostFavButton extends ConsumerWidget {
  const PostFavButton({super.key, required this.post, this.iconSize, this.visualDensity});
  final Post post;
  final double? iconSize;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
      favoritesProvider.select((list) => list.any((f) => f.id == post.id)),
    );
    return IconButton(
      icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_outline),
      iconSize: iconSize ?? 24,
      visualDensity: visualDensity,
      tooltip: isFav ? 'Убрать из избранного' : 'В избранное',
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(FavoritePost.fromPost(post)),
    );
  }
}

class DarkSidePostFavButton extends ConsumerWidget {
  const DarkSidePostFavButton({super.key, required this.post, this.iconSize, this.visualDensity});
  final DarkSidePost post;
  final double? iconSize;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
      darkSideFavoritesProvider.select((list) => list.any((f) => f.id == post.id)),
    );
    return IconButton(
      icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_outline),
      iconSize: iconSize ?? 24,
      visualDensity: visualDensity,
      tooltip: isFav ? 'Убрать из избранного' : 'В избранное',
      onPressed: () => ref
          .read(darkSideFavoritesProvider.notifier)
          .toggle(FavoriteDarkSidePost.fromPost(post)),
    );
  }
}
