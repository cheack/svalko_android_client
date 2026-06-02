import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
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
import '../../ui/skin_ext.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId, this.highlightCommentId, this.showShuffle = false});

  final int postId;
  final int? highlightCommentId;
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
  bool _pendingScrollToBottom = false;
  bool _fabVisible = true;
  double _lastScrollOffset = 0;
  bool _loadingRandom = false;
  PostRating? _rating;
  int? _borodaCount;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(postControllerProvider(widget.postId).notifier).refresh();
      }
      if (widget.highlightCommentId != null) _tryScrollToHighlight();
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
    if (diff > 4 && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (diff < -4 && !_fabVisible) {
      setState(() => _fabVisible = true);
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Called BEFORE loadPage so the layout is still stable.
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
    if (_didScrollToHighlight) return;
    final state = ref.read(postControllerProvider(widget.postId));
    if (state.isLoading || state.totalPages != 1) return;
    final ctx = _highlightKey.currentContext;
    if (ctx == null) return;
    _didScrollToHighlight = true;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _scrollToComments() {
    final target = _commentsTarget;
    if (target == null || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
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

    ref.listen<PostState>(postControllerProvider(widget.postId), (prev, next) {
      if (prev?.isLoadingMore == true && !next.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pendingScrollToBottom) {
            _pendingScrollToBottom = false;
            _scrollToBottom();
          } else {
            _scrollToComments();
          }
        });
      }
      if (prev?.isLoading == true && !next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToHighlight());
      }
    });
    final s = AppStrings.of(ref.watch(languageProvider));

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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoadingMore ? null : ctrl.refresh,
          ),
          PostShareButton(postId: post.id),
          PostFavButton(post: post),
        ],
      ),
      floatingActionButton: AnimatedSlide(
        offset: _fabVisible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            onPressed: () async {
              final sent = await showCommentSheet(context, api, settingsBox, post.id);
              if (sent && mounted) {
                _pendingScrollToBottom = true;
                ctrl.loadLastPage();
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Написать'),
          ),
        ),
      ),
      body: SelectionArea(
        child: RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: Scrollbar(
        controller: _scrollController,
        child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Builder(builder: (ctx) {
            final dividers = Theme.of(ctx).extension<SvalkoSkinExt>()?.cardDividers ?? false;
            return Padding(
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
                      onAuthorTap: () => Navigator.of(context)
                          .pushNamed('/author', arguments: post.author),
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
          );
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
            _CommentPageBar(
              totalPages: state.totalPages,
              currentPage: state.currentPage,
              isLoading: state.isLoadingMore,
              onPageTap: (page) {
                _captureCommentsTarget();
                ctrl.loadPage(page);
              },
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
                    ),
                  ],
                ],
              );
            }),
          ),
          // Bottom page bar
          if (state.totalPages > 1)
            _CommentPageBar(
              totalPages: state.totalPages,
              currentPage: state.currentPage,
              isLoading: state.isLoadingMore,
              onPageTap: (page) {
                _captureCommentsTarget();
                ctrl.loadPage(page);
              },
            ),
        ],
      ),
      ),
      ),
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
              child: Text('$slot', style: const TextStyle(fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
