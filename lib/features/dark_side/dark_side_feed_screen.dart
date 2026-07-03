import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dark_side_post.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/image_carousel.dart';
import '../../ui/widgets/post_header.dart';
import '../feed/widgets/page_nav_panel.dart';
import '../navigation/app_drawer.dart';
import 'dark_side_feed_controller.dart';

class DarkSideFeedScreen extends ConsumerWidget {
  const DarkSideFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(darkSideFeedControllerProvider);
    final ctrl = ref.read(darkSideFeedControllerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: buildBlurAppBar(
        context,
        title: const Text('Тёмная сторона свалки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: state.isRefreshing ? null : ctrl.refresh,
          ),
        ],
      ),
      body: _buildBody(context, state, ctrl),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DarkSideFeedState state,
    DarkSideFeedController ctrl,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error.toString()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: ctrl.loadInitial,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (state.posts.isEmpty) {
      return const Center(child: Text('Постов не найдено'));
    }

    final currentPage = state.currentPage ?? 0;
    final maxPage = state.maxPage ?? currentPage;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: ctrl.refresh,
          edgeOffset: blurAppBarTopPadding(context),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
                ctrl.loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: EdgeInsets.only(top: blurAppBarTopPadding(context)),
              itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                if (i == state.posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _DarkSidePostTile(post: state.posts[i]);
              },
            ),
          ),
        ),
        if (currentPage < maxPage || currentPage > 0)
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: PageNavPanel(
                currentPage: currentPage,
                maxPage: maxPage,
                canGoNewer: currentPage < maxPage,
                canGoOlder: currentPage > 0,
                isLoading: state.isRefreshing,
                onNewer: () => ctrl.loadPage(currentPage + 1),
                onOlder: () => ctrl.loadPage(currentPage - 1),
                onPageSelected: ctrl.loadPage,
              ),
            ),
          ),
      ],
    );
  }
}

class _DarkSidePostTile extends StatelessWidget {
  const _DarkSidePostTile({required this.post});

  final DarkSidePost post;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            author: post.author.isEmpty ? 'Аноним' : post.author,
            publishedAt: post.publishedAt,
          ),
          if (post.imageUrls.isNotEmpty)
            ImageCarousel(urls: post.imageUrls, maxHeight: 400),
          if (post.text != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(post.text!),
            ),
        ],
      );
}
