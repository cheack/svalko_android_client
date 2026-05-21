import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import 'post_controller.dart';
import 'widgets/comment_tile.dart';
import '../../ui/widgets/image_carousel.dart';
import '../../ui/widgets/linked_text.dart';
import '../../ui/widgets/media_actions.dart';
import '../../ui/widgets/post_tags.dart';
import '../../ui/widgets/video_player_widget.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId, this.highlightCommentId});

  final int postId;
  final int? highlightCommentId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey();
  final _highlightKey = GlobalKey();
  double? _commentsTarget;
  bool _didScrollToHighlight = false;

  @override
  void initState() {
    super.initState();
    if (widget.highlightCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToHighlight());
    }
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

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider(widget.postId));
    final ctrl = ref.read(postControllerProvider(widget.postId).notifier);

    ref.listen<PostState>(postControllerProvider(widget.postId), (prev, next) {
      if (prev?.isLoadingMore == true && !next.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComments());
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

    return Scaffold(
      appBar: AppBar(title: Text(post.author.name)),
      body: SelectionArea(
        child: Scrollbar(
        controller: _scrollController,
        child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context)
                      .pushNamed('/author', arguments: post.author),
                  child: Text(
                    post.author.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                Text(
                  '  ${_fmt(post.publishedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Post images
          if (post.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ImageCarousel(urls: post.imageUrls, maxHeight: 480),
            ),
          // Post videos
          for (final url in post.videoUrls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onLongPress: () => showMediaSheet(context, url, isVideo: true),
                child: VideoPlayerWidget(url: url),
              ),
            ),
          // Post text
          if (post.text != null && post.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: LinkedText(
                post.text!,
                onSvalkoPost: (id) =>
                    Navigator.of(context).pushNamed('/post', arguments: id),
              ),
            ),
          // Tags
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: PostTagsRow(tags: post.tags),
            ),
          // Rating
          if (post.rating != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                '${s.rating}: +${post.rating!.plus} | ${post.rating!.neutral} | ${post.rating!.minus} = ${post.rating!.percentage}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
            child: Column(
              children: [
                for (final comment in state.comments)
                  CommentTile(
                    key: comment.id == widget.highlightCommentId
                        ? _highlightKey
                        : null,
                    comment: comment,
                  ),
              ],
            ),
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
