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
  const PostScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey();
  double? _commentsTarget;

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
      body: Scrollbar(
        controller: _scrollController,
        child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              '${post.author.name}  ${_fmt(post.publishedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
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
                  CommentTile(comment: comment),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(totalPages, (i) {
          final isCurrent = i == currentPage;
          return SizedBox(
            width: 36,
            height: 32,
            child: FilledButton.tonal(
              onPressed: isLoading || isCurrent ? null : () => onPageTap(i),
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
              child: Text('$i', style: const TextStyle(fontSize: 12)),
            ),
          );
        }),
      ),
    );
  }
}
