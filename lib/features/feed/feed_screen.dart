import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../models/feed_source.dart';
import '../navigation/app_drawer.dart';
import '../search/search_controller.dart';
import '../search/search_dialog.dart';
import 'ban_screen.dart';
import 'feed_controller.dart';
import 'widgets/calendar_sheet.dart';
import 'widgets/page_nav_panel.dart';
import 'widgets/post_card.dart';
import '../../ui/skin_ext.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/marquee_title.dart';

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
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final source = widget.source;
      ref.read(activeTagProvider.notifier).state =
          source is TagFeed ? source.tagName : null;
    });
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

    for (final entry in _pageKeys.entries) {
      final box =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      _pageScrollOffsets[entry.key] =
          S + box.localToGlobal(Offset.zero).dy - appBarH;
    }

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

  String _title(AppStrings s) => switch (widget.source) {
        MainFeed() => s.appTitle,
        TagFeed(:final tagName) => '#$tagName',
        AuthorFeed(:final authorName) => authorName,
        ApproverFeed(:final approverName) => 'одобрено: $approverName',
        DateFeed(:final label) => label,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider(widget.source));
    final ctrl = ref.read(feedControllerProvider(widget.source).notifier);
    final s = AppStrings.of(ref.watch(languageProvider));
    final fontSize = ref.watch(fontSizeProvider);

    // After loadPage/refresh: reset offsets, update page, jump to top.
    ref.listen<FeedState>(feedControllerProvider(widget.source), (prev, next) {
      if (prev?.isRefreshing == true &&
          !next.isRefreshing &&
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

    ref.listen<SiteMode>(siteModeProvider, (prev, next) {
      if (prev != null) {
        _pageKeys.clear();
        _pageScrollOffsets.clear();
        setState(() => _visiblePage = null);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        });
      }
    });

    if (_visiblePage == null && state.currentPage != null) {
      _visiblePage = state.currentPage;
      _pageScrollOffsets[state.currentPage!] = 0;
    }

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.banData != null) {
      return BanScreen(
        banData: state.banData!,
        isLoading: state.isLoading,
        onSubmit: ctrl.submitBanAnswer,
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

    if (state.error == null && state.posts.isEmpty && !state.hasMore) {
      return Scaffold(
        appBar: AppBar(title: Text(_title(s))),
        body: Center(child: Text(s.noPostsFound)),
      );
    }

    final indexToPage = <int, int>{
      for (final e in state.pageFirstIndex.entries) e.value: e.key,
    };
    final visiblePage = _visiblePage;

    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      drawer: AppDrawer(activePage: widget.source is MainFeed ? 'home' : null),
      drawerEdgeDragWidth: 80,
      appBar: buildBlurAppBar(
        context,
        title: MarqueeTitle(_title(s)),
        titleSpacing: 8,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Поиск',
            onPressed: () async {
              final params = await showSearchDialog(context, ref);
              if (params == null || !mounted) return;
              ref.read(lastSearchParamsProvider.notifier).state = params;
              // ignore: use_build_context_synchronously
              Navigator.of(context).pushNamed('/search', arguments: params);
            },
          ),
          if (state.calendar != null)
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Календарь',
              onPressed: () async {
                final source = await showModalBottomSheet<DateFeed>(
                  context: context,
                  isScrollControlled: true,
                  routeSettings: const RouteSettings(name: '/calendar'),
                  builder: (_) => CalendarSheet(
                    fallbackMonth: state.calendar!,
                  ),
                );
                if (source == null || !mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FeedScreen(source: source)),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.refresh,
            onPressed: state.isRefreshing ? null : ctrl.refresh,
          ),
        ],
      ),
      body: Builder(
        builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
        ),
        child: Stack(
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
                padding: EdgeInsets.only(
                  top: blurAppBarTopPadding(context),
                  left: landscapeHPadding(context),
                  right: landscapeHPadding(context),
                ),
                itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = state.posts[i];
                  final pageAtIndex = indexToPage[i];
                  final useDividers = Theme.of(ctx).extension<SvalkoSkinExt>()?.cardDividers ?? false;
                  Widget card = PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => Navigator.of(ctx).pushNamed(
                      '/post',
                      arguments: post.id,
                    ),
                    showApproverTap: widget.source is! ApproverFeed,
                  );
                  if (pageAtIndex != null) card = KeyedSubtree(key: _keyFor(pageAtIndex), child: card);
                  if (useDividers && i > 0) {
                    card = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1, thickness: 1),
                        card,
                      ],
                    );
                  }
                  return card;
                },
              ),
            ),
          ),
          if (visiblePage != null &&
              (visiblePage < (state.maxPage ?? visiblePage) ||
                  visiblePage > 0))
            Positioned(
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: PageNavPanel(
                  currentPage: visiblePage,
                  maxPage: state.maxPage ?? visiblePage,
                  canGoNewer: visiblePage < (state.maxPage ?? visiblePage),
                  canGoOlder: visiblePage > 0,
                  isLoading: state.isRefreshing,
                  onNewer: () => ctrl.loadPage(visiblePage + 1),
                  onOlder: () => ctrl.loadPage(visiblePage - 1),
                  onPageSelected: ctrl.loadPage,
                ),
              ),
            ),
        ],
        ),
        ),
      ),
    );

    if (widget.source is! MainFeed) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нажмите назад ещё раз для выхода'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: scaffold,
    );
  }
}
