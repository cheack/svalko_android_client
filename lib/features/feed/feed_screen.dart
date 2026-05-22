import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../models/feed_source.dart';
import '../navigation/app_drawer.dart';
import 'feed_controller.dart';
import 'widgets/post_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.source = const MainFeed()});

  final FeedSource source;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();
  final _pageKeys = <int, GlobalKey>{};
  // Absolute scroll offset at which each page's first post is at viewport top.
  // Populated while the marker is rendered; survives after it's disposed.
  final _pageScrollOffsets = <int, double>{};
  int? _visiblePage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int page) => _pageKeys.putIfAbsent(page, GlobalKey.new);

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final S = _scrollController.offset;
    final appBarH = kToolbarHeight + MediaQuery.of(context).padding.top;

    // Update stored offsets for any page markers currently in the render tree.
    for (final entry in _pageKeys.entries) {
      final box =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      _pageScrollOffsets[entry.key] =
          S + box.localToGlobal(Offset.zero).dy - appBarH;
    }

    // Visible page = the highest-offset page whose start is at or above the
    // top of the viewport (offset <= current scroll).
    int? best;
    double bestOff = double.negativeInfinity;
    for (final entry in _pageScrollOffsets.entries) {
      if (entry.value <= S && entry.value > bestOff) {
        bestOff = entry.value;
        best = entry.key;
      }
    }

    if (best != null && best != _visiblePage) {
      setState(() => _visiblePage = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider(widget.source));
    final ctrl = ref.read(feedControllerProvider(widget.source).notifier);
    final s = AppStrings.of(ref.watch(languageProvider));

    // After loadPage/refresh: reset offsets, update page, jump to top.
    ref.listen<FeedState>(feedControllerProvider(widget.source), (prev, next) {
      if (prev?.isRefreshing == true && !next.isRefreshing &&
          next.currentPage != null) {
        _pageScrollOffsets
          ..clear()
          ..[next.currentPage!] = 0;
        setState(() => _visiblePage = next.currentPage);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        });
      }
    });

    // Initialise on first data load.
    if (_visiblePage == null && state.currentPage != null) {
      _visiblePage = state.currentPage;
      _pageScrollOffsets[state.currentPage!] = 0;
    }

    final indexToPage = <int, int>{
      for (final e in state.pageFirstIndex.entries) e.value: e.key,
    };

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error == null && state.posts.isEmpty && !state.hasMore) {
      return Scaffold(
        appBar: AppBar(
          title: Text(switch (widget.source) {
            MainFeed() => s.appTitle,
            TagFeed(:final tagName) => '#$tagName',
            AuthorFeed(:final authorName) => authorName,
          }),
        ),
        body: Center(child: Text(s.noPostsFound)),
      );
    }

    if (state.error != null && state.posts.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error.toString()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: ctrl.loadInitial,
                child: Text(s.retry),
              ),
            ],
          ),
        ),
      );
    }

    final visiblePage = _visiblePage;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(switch (widget.source) {
          MainFeed() => s.appTitle,
          TagFeed(:final tagName) => '#$tagName',
          AuthorFeed(:final authorName) => authorName,
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.refresh,
            onPressed: state.isRefreshing ? null : ctrl.refresh,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: ctrl.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification &&
                    n.metrics.extentAfter < 200) {
                  ctrl.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    state.posts.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = state.posts[i];
                  final pageAtIndex = indexToPage[i];
                  return PostCard(
                    key: pageAtIndex != null ? _keyFor(pageAtIndex) : null,
                    post: post,
                    onTap: () => Navigator.of(ctx).pushNamed(
                      '/post',
                      arguments: post.id,
                    ),
                  );
                },
              ),
            ),
          ),
          if (visiblePage != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _PageNavPanel(
                  currentPage: visiblePage,
                  canGoNewer: visiblePage < (state.maxPage ?? visiblePage),
                  canGoOlder: visiblePage > 0,
                  isLoading: state.isRefreshing,
                  onNewer: () => ctrl.loadPage(visiblePage + 1),
                  onOlder: () => ctrl.loadPage(visiblePage - 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageNavPanel extends StatelessWidget {
  const _PageNavPanel({
    required this.currentPage,
    required this.canGoNewer,
    required this.canGoOlder,
    required this.isLoading,
    required this.onNewer,
    required this.onOlder,
  });

  final int currentPage;
  final bool canGoNewer;
  final bool canGoOlder;
  final bool isLoading;
  final VoidCallback onNewer;
  final VoidCallback onOlder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: 'Новее',
              visualDensity: VisualDensity.compact,
              onPressed: (!isLoading && canGoNewer) ? onNewer : null,
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'стр. $currentPage',
                        style: theme.textTheme.bodyMedium,
                      ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18),
              tooltip: 'Старее',
              visualDensity: VisualDensity.compact,
              onPressed: (!isLoading && canGoOlder) ? onOlder : null,
            ),
          ],
        ),
      ),
    );
  }
}
