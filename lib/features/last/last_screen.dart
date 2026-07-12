import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/last_item.dart';
import '../../ui/skin_ext.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/font_scaled_body.dart';
import '../navigation/app_drawer.dart';
import 'last_controller.dart';

class LastScreen extends ConsumerWidget {
  const LastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lastProvider);
    final theme = Theme.of(context);
    final appBarFg = theme.appBarTheme.foregroundColor ?? Colors.white;

    final notifier = ref.read(lastProvider.notifier);
    final skip = async.hasValue ? ref.watch(lastProvider.notifier).skip : 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: const AppDrawer(activePage: 'last'),
        drawerEdgeDragWidth: 80,
        appBar: buildBlurAppBar(
          context,
          title: const Text('Ласты'),
          actions: [
            if (skip > 0)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                tooltip: 'Предыдущие',
                onPressed: async.isLoading ? null : notifier.loadPrev,
              ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              tooltip: 'Следующие',
              onPressed: async.isLoading ? null : notifier.loadNext,
            ),
          ],
          bottom: TabBar(
            labelColor: appBarFg,
            unselectedLabelColor: appBarFg.withAlpha(153),
            indicatorColor: appBarFg,
            tabs: const [
              Tab(text: 'Комментарии'),
              Tab(text: 'Картинки'),
            ],
          ),
        ),
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.of(context).padding.copyWith(
              top: blurAppBarTopPadding(context, bottomHeight: kTextTabBarHeight),
            ),
          ),
          child: FontScaledBody(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.toString()),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        ref.read(lastProvider.notifier).refresh(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
            data: (data) {
              final (comments, images) = data;
              return TabBarView(
                children: [
                  _CommentsTab(
                    comments: comments,
                    onRefresh: () =>
                        ref.read(lastProvider.notifier).refresh(),
                  ),
                  _ImagesTab(
                    images: images,
                    onRefresh: () =>
                        ref.read(lastProvider.notifier).refresh(),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({required this.comments, required this.onRefresh});
  final List<LastComment> comments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skinExt = theme.extension<SvalkoSkinExt>();
    final dividers = skinExt?.cardDividers ?? false;
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: MediaQuery.of(context).padding.top,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
          left: landscapeHPadding(context),
          right: landscapeHPadding(context),
        ),
        itemCount: comments.length,
        itemBuilder: (ctx, i) {
          final c = comments[i];
          final topicRow = InkWell(
            onTap: () => Navigator.of(ctx)
                .pushNamed('/post', arguments: c.postId),
            child: Padding(
              padding: dividers
                  ? const EdgeInsets.fromLTRB(12, 10, 12, 4)
                  : const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Тема: ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (c.postTitle.isNotEmpty)
                          TextSpan(
                            text: c.postTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: cs.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: cs.primary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      children: [
                        if (c.topicAge == TopicAge.veryOld) ...[
                          const TextSpan(
                            text: 'очень старая тема',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ', '),
                        ] else if (c.topicAge == TopicAge.old) ...[
                          const TextSpan(
                            text: 'старая тема',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ', '),
                        ],
                        TextSpan(text: '${c.commentCount} комментариев'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          final card = GestureDetector(
            onTap: () => Navigator.of(ctx)
                .pushNamed('/post', arguments: (c.postId, c.commentId)),
            child: SkinCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkinHeader(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Text(
                        c.author,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: cs.primary),
                      ),
                    ),
                  ),
                  if (c.commentText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                      child: Text(
                        c.commentText,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          );

          final padding = dividers
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(8, 0, 8, 0);

          if (dividers && i > 0) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, thickness: 1),
                topicRow,
                Padding(padding: padding, child: card),
                const SizedBox(height: 12),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topicRow,
              Padding(padding: padding, child: card),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _ImagesTab extends StatelessWidget {
  const _ImagesTab({required this.images, required this.onRefresh});
  final List<LastImage> images;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: MediaQuery.of(context).padding.top,
      child: GridView.builder(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 4,
          right: 4,
          bottom: 4,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: images.length,
        itemBuilder: (ctx, i) {
          final img = images[i];
          return InkWell(
            onTap: () => Navigator.of(ctx).pushNamed(
              '/post',
              arguments: (img.postId, img.commentId),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: img.thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const ColoredBox(color: Color(0x18808080)),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: Text(
                      img.author,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
