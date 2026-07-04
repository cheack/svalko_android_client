import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_storage.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../feed/widgets/page_nav_panel.dart';
import '../navigation/app_drawer.dart';
import 'dark_side_feed_controller.dart';
import 'dark_side_post_tile.dart';

class DarkSideFeedScreen extends ConsumerWidget {
  const DarkSideFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(darkSideFeedControllerProvider);
    final ctrl = ref.read(darkSideFeedControllerProvider.notifier);
    final fontSize = ref.watch(fontSizeProvider);

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
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
        ),
        child: _buildBody(context, state, ctrl),
      ),
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
              padding: EdgeInsets.only(
                top: blurAppBarTopPadding(context),
                left: landscapeHPadding(context),
                right: landscapeHPadding(context),
              ),
              itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                if (i == state.posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // SelectionArea per item, not around the whole scrollable list —
                // wrapping a Scrollable whose item count changes during a
                // drag-selection trips a Flutter framework assertion
                // ('!_selectionStartsInScrollable').
                return SelectionArea(child: DarkSidePostTile(post: state.posts[i]));
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
