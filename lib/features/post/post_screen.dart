import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import '../../features/favorites/favorites_storage.dart';
import '../../ui/widgets/post_action_buttons.dart';
import '../feed/feed_controller.dart';
import 'post_controller.dart';
import 'widgets/comment_tile.dart';
import '../../ui/widgets/image_carousel.dart';
import '../../ui/widgets/comment_html.dart';
import '../../ui/widgets/comment_input_sheet.dart';
import '../../ui/widgets/media_actions.dart';
import '../../ui/widgets/post_tags.dart';
import '../../ui/widgets/post_vote_section.dart';
import '../../ui/widgets/post_header.dart';
import '../../ui/widgets/video_embed_player.dart';
import '../../ui/widgets/video_link_card.dart';
import '../../ui/widgets/video_player_widget.dart';
import '../../core/result.dart';
import '../../models/post.dart';
import '../../models/feed_source.dart';
import '../../ui/skin_ext.dart';
import '../../ui/widgets/kum_shake.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId, this.highlightCommentId, this.initialCommentPage, this.showShuffle = false});

  final int postId;
  final int? highlightCommentId;
  final int? initialCommentPage;
  final bool showShuffle;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey();
  final _highlightKey = GlobalKey();
  double? _commentsTarget;
  bool _didScrollToHighlight = false;
  int _scrollRetries = 0;
  bool _pendingScrollToBottom = false;
  bool _pendingScrollToComments = false;
  int _pinFrames = 0; // frames left to keep the comments header pinned to top
  bool _searchingDown = false; // walking down from the top to find the header
  bool _topVisible = false;
  double _lastScrollOffset = 0;
  bool _didNavigateToInitialPage = false;
  bool _pendingScrollToHighlight = false;
  bool _loadingRandom = false;
  PostRating? _rating;
  int? _borodaCount;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialCommentPage == null) {
        ref.read(postControllerProvider(widget.postId).notifier).refresh();
      }
      if (widget.highlightCommentId != null && widget.initialCommentPage == null) _tryScrollToHighlight();
    });
  }

  Future<void> _openRandom() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    final result = await ref.read(repositoryProvider).getRandomPostId();
    if (!mounted) return;
    setState(() => _loadingRandom = false);
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pushReplacementNamed('/random-post', arguments: value);
      case Err(:final error):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final diff = offset - _lastScrollOffset;
    if (diff > 1 && !_topVisible) {
      setState(() => _topVisible = true);
    }
    if (offset < 50 && _topVisible) {
      setState(() => _topVisible = false);
    }
    _lastScrollOffset = offset;
    // Capture while the header passes through the viewport — the lazy
    // ListView disposes it once it's far off-screen, so capturing only at
    // page-tap time fails if the user scrolled straight to the bottom bar.
    _captureCommentsTarget();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Remembers the absolute offset of the comments header. Only works while
  // the header is built (in or near the viewport), so it's captured
  // opportunistically: after the post loads, on every scroll tick, on page
  // tap, and on every frame of the pin loop.
  void _captureCommentsTarget() {
    final ctx = _commentsKey.currentContext;
    if (ctx == null || !_scrollController.hasClients) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    _commentsTarget = _scrollController.offset +
        box.localToGlobal(Offset.zero).dy -
        appBarHeight;
  }

  void _tryScrollToHighlight() {
    if (widget.highlightCommentId == null) return;
    if (_didScrollToHighlight) return;
    final state = ref.read(postControllerProvider(widget.postId));
    if (state.isLoading || state.isLoadingMore) return;
    final ctx = _highlightKey.currentContext;
    if (ctx == null) {
      // Item not yet built by ListView — jump to estimated position to bring it into viewport.
      if (_scrollRetries < 3 && _scrollController.hasClients && state.comments.isNotEmpty) {
        _scrollRetries++;
        final matchIdx = state.comments.indexWhere((c) => c.id == widget.highlightCommentId);
        if (matchIdx >= 0) {
          final max = _scrollController.position.maxScrollExtent;
          final target = (max * matchIdx / state.comments.length).clamp(0.0, max);
          _scrollController.jumpTo(target);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryScrollToHighlight();
        });
      }
      return;
    }
    _scrollRetries = 0;
    _didScrollToHighlight = true;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    // Images loading above the target shift the layout — re-scroll a few times.
    for (final ms in [400, 900, 1800]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        final c = _highlightKey.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(c,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    }
  }

  // After a page change: jump instantly to the remembered header position,
  // then pin it to the top for a few frames while the layout settles.
  // No animation — an animated scroll gives the lazy list a 300ms window to
  // shift the layout under us, which is what made this unreliable.
  void _settleScrollToComments() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      _scrollController.jumpTo(
          (_commentsTarget ?? 0.0).clamp(0.0, pos.maxScrollExtent));
    }
    _searchingDown = false;
    _pinFrames = 90;
    _pinCommentsHeader();
  }

  void _pinCommentsHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinFrames-- <= 0) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final ctx = _commentsKey.currentContext;
      if (ctx == null) {
        // Header isn't laid out — the guess was off by more than a viewport.
        // Restart from the top and walk down one viewport per frame: this
        // lays everything out for real (no estimates) until it's built.
        final next =
            _searchingDown ? pos.pixels + pos.viewportDimension : 0.0;
        _searchingDown = true;
        _scrollController.jumpTo(next.clamp(0.0, pos.maxScrollExtent));
      } else {
        _searchingDown = false;
        _captureCommentsTarget();
        final to = _commentsTarget!.clamp(0.0, pos.maxScrollExtent);
        if ((to - pos.pixels).abs() > 1) _scrollController.jumpTo(to);
      }
      _pinCommentsHeader();
    });
  }

  void _loadCommentsPage(int page, {bool settleToComments = true}) {
    _captureCommentsTarget();
    _pendingScrollToComments = settleToComments;
    ref.read(postControllerProvider(widget.postId).notifier).loadPage(page);
  }

  void _resetHighlightScroll() {
    _didScrollToHighlight = false;
    _scrollRetries = 0;
  }

  void _scrollToHighlightAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryScrollToHighlight();
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    setState(() => _topVisible = false);
    _pinFrames = 0;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _pinFrames = 0; // don't let the pin loop fight this animation
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider(widget.postId));
    final ctrl = ref.read(postControllerProvider(widget.postId).notifier);

    if (widget.initialCommentPage != null &&
        !_didNavigateToInitialPage &&
        !state.isLoading &&
        !state.isLoadingMore &&
        state.post != null) {
      final page = widget.initialCommentPage!;
      _resetHighlightScroll();
      if (page != state.currentPage) {
        _pendingScrollToHighlight = widget.highlightCommentId != null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(postControllerProvider(widget.postId));
          if (current.isLoading || current.isLoadingMore) return;
          _didNavigateToInitialPage = true;
          _loadCommentsPage(page, settleToComments: false);
        });
      } else if (widget.highlightCommentId != null) {
        _didNavigateToInitialPage = true;
        _scrollToHighlightAfterLayout();
      } else {
        _didNavigateToInitialPage = true;
      }
    }

    ref.listen<PostState>(postControllerProvider(widget.postId), (prev, next) {
      if (prev?.isLoadingMore == true && !next.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pendingScrollToBottom) {
            _pendingScrollToBottom = false;
            _scrollToBottom();
          } else if (_pendingScrollToComments) {
            _pendingScrollToComments = false;
            _settleScrollToComments();
          }
          if (_pendingScrollToHighlight) {
            _pendingScrollToHighlight = false;
            _resetHighlightScroll();
            _scrollToHighlightAfterLayout();
          }
        });
      }
      if (prev?.isLoading == true && !next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Remember the header position right away — the first guess for
          // page-change jumps even if the user never scrolls past it.
          _captureCommentsTarget();
          if (widget.initialCommentPage == null) _tryScrollToHighlight();
        });
      }
    });
    final s = AppStrings.of(ref.watch(languageProvider));
    final fontSize = ref.watch(fontSizeProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error.toString()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: ctrl.load,
                child: Text(s.retry),
              ),
            ],
          ),
        ),
      );
    }

    final post = state.post!;

    final api = ref.read(apiProvider);
    final settingsBox = ref.read(settingsBoxProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.author.name),
        actions: [
          if (widget.showShuffle)
            if (_loadingRandom)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: _openRandom,
              ),
          _PostMenu(post: post, scrollController: _scrollController),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _topVisible
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FloatingActionButton.small(
                      heroTag: 'scroll_top',
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.arrow_upward),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          FloatingActionButton.extended(
            heroTag: 'write',
            onPressed: () async {
              final sent = await showCommentSheet(context, api, settingsBox, post.id);
              if (sent && mounted) {
                _pendingScrollToBottom = true;
                _pendingScrollToComments = false;
                ctrl.loadLastPage();
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Написать'),
          ),
        ],
      ),
      body: Builder(
        builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
        ),
        child: SelectionArea(
        child: RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          // User grabbed the list — stop pinning the comments header.
          if (n.dragDetails != null) _pinFrames = 0;
          return false;
        },
        child: Scrollbar(
        controller: _scrollController,
        child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 88 + MediaQuery.of(context).padding.bottom),
        children: [
          Builder(builder: (ctx) {
            final dividers = Theme.of(ctx).extension<SvalkoSkinExt>()?.cardDividers ?? false;
            return KumShake(
            enabled: post.isKum,
            child: Padding(
            padding: dividers ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainer,
                image: Theme.of(ctx).extension<SvalkoSkinExt>()?.cardPattern,
                borderRadius: dividers ? null : BorderRadius.circular(4),
                border: dividers ? null : Border.all(
                  color: Theme.of(ctx).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkinHeader(
                    child: PostHeader(
                      author: post.author.name,
                      publishedAt: post.publishedAt,
                      rating: _rating ?? post.rating,
                      borodaCount: _borodaCount ?? post.borodaCount,
                      approvedBy: post.approvedBy,
                      onAuthorTap: () => Navigator.of(context)
                          .pushNamed('/author', arguments: post.author),
                      onDateTap: () => navigateToDateFeed(context, ref, post.publishedAt),
                      onApprovedByTap: post.approvedBy == null
                          ? null
                          : () => Navigator.of(context).pushNamed('/approver',
                              arguments: ApproverFeed(approverName: post.approvedBy!)),
                    ),
                  ),
                  if (post.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ImageCarousel(urls: post.imageUrls, maxHeight: 480),
                    ),
                  for (final url in post.videoUrls)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onLongPress: () => showMediaSheet(context, url, isVideo: true),
                        child: VideoPlayerWidget(url: url),
                      ),
                    ),
                  for (final link in post.externalLinks)
                    if (VideoEmbedPlayer.isSupported(link))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: VideoEmbedPlayer(url: link),
                      )
                    else if (VideoLinkCard.isSupported(link))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: VideoLinkCard(url: link),
                      ),
                  if (post.textHtml != null && post.textHtml!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: CommentHtml(
                        post.textHtml!,
                        onSvalkoPost: (id) =>
                            Navigator.of(context).pushNamed('/post', arguments: id),
                      ),
                    ),
                  if (post.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: PostTagsRow(tags: post.tags),
                    ),
                  PostVoteSection(
                    postId: post.id,
                    rating: post.rating,
                    borodaCount: post.borodaCount,
                    parsedVote: post.parsedVote,
                    parsedBoroda: post.parsedBoroda,
                    availableVotes: post.availableVotes,
                    onRatingChanged: (r, bc) => setState(() {
                      _rating = r;
                      _borodaCount = bc;
                    }),
                  ),
                ],
              ),
            ),
          ));
          }),
          const Divider(height: 24),
          // Comments section header — anchor for scroll
          Padding(
            key: _commentsKey,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              s.commentsHeader(state.totalComments),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          // Top page bar
          if (state.totalPages > 1)
            KumShake(
              enabled: state.paginationIsKum,
              child: _CommentPageBar(
                totalPages: state.totalPages,
                currentPage: state.currentPage,
                isLoading: state.isLoadingMore,
                onPageTap: _loadCommentsPage,
              ),
            ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: state.isLoadingMore ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Builder(builder: (ctx) {
              final dividers = Theme.of(ctx).extension<SvalkoSkinExt>()?.cardDividers ?? false;
              return Column(
                children: [
                  for (int i = 0; i < state.comments.length; i++) ...[
                    if (dividers && i > 0) const Divider(height: 1, thickness: 1),
                    CommentTile(
                      key: state.comments[i].id == widget.highlightCommentId
                          ? _highlightKey
                          : null,
                      comment: state.comments[i],
                      currentPage: state.currentPage,
                      isHighlighted: state.comments[i].id == widget.highlightCommentId,
                    ),
                  ],
                ],
              );
            }),
          ),
          // Bottom page bar
          if (state.totalPages > 1)
            KumShake(
              enabled: state.paginationIsKum,
              child: _CommentPageBar(
                totalPages: state.totalPages,
                currentPage: state.currentPage,
                isLoading: state.isLoadingMore,
                onPageTap: _loadCommentsPage,
              ),
            ),
        ],
      ),
      ),
      ),
      ),
      ),
      ),
      ),
    );
  }
}

class _PostMenu extends ConsumerStatefulWidget {
  const _PostMenu({required this.post, required this.scrollController});
  final Post post;
  final ScrollController scrollController;

  @override
  ConsumerState<_PostMenu> createState() => _PostMenuState();
}

class _PostMenuState extends ConsumerState<_PostMenu> {
  final _menuController = MenuController();

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_menuController.isOpen) _menuController.close();
  }

  void _toggleFav() {
    final post = widget.post;
    ref.read(favoritesProvider.notifier).toggle(
          FavoritePost(
            id: post.id,
            authorName: post.author.name,
            publishedAt: post.publishedAt,
            addedAt: DateTime.now(),
            firstImageUrl: post.imageUrls.firstOrNull,
            previewText: post.text != null && post.text!.isNotEmpty
                ? post.text!.substring(0, post.text!.length.clamp(0, 120))
                : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isFav = ref.watch(
      favoritesProvider.select((list) => list.any((f) => f.id == post.id)),
    );
    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.share_outlined),
          onPressed: () => Share.share(PostShareButton.postUrl(post.id)),
          child: const Text('Поделиться'),
        ),
        MenuItemButton(
          leadingIcon: Icon(isFav ? Icons.bookmark : Icons.bookmark_outline),
          onPressed: _toggleFav,
          child: Text(isFav ? 'Убрать из избранного' : 'В избранное'),
        ),
      ],
      builder: (_, controller, _) => IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _CommentPageBar extends StatelessWidget {
  const _CommentPageBar({
    required this.totalPages,
    required this.currentPage,
    required this.isLoading,
    required this.onPageTap,
  });

  final int totalPages;
  final int currentPage;
  final bool isLoading;
  final void Function(int) onPageTap;

  // Returns a list of page indices and -1 as a sentinel for "...".
  List<int> _buildPageSlots() {
    if (totalPages <= 9) {
      return List.generate(totalPages, (i) => i);
    }
    final last = totalPages - 1;
    final Set<int> pages = {
      0,
      1,
      last - 1,
      last,
      currentPage - 2,
      currentPage - 1,
      currentPage,
      currentPage + 1,
      currentPage + 2,
    };
    final sorted = pages.where((p) => p >= 0 && p <= last).toList()..sort();

    final result = <int>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add(-1);
      result.add(sorted[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = _buildPageSlots();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: slots.map((slot) {
          if (slot == -1) {
            return SizedBox(
              width: 24,
              height: 32,
              child: Center(
                child: Text(
                  '…',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          final isCurrent = slot == currentPage;
          return SizedBox(
            width: 36,
            height: 32,
            child: FilledButton.tonal(
              onPressed: isLoading || isCurrent ? null : () => onPageTap(slot),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHigh,
                foregroundColor: isCurrent
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                disabledForegroundColor: isCurrent
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.6)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                disabledBackgroundColor: isCurrent
                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                    : theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$slot', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
