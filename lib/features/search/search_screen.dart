import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/search_result.dart';
import '../../ui/skin_ext.dart';
import '../../ui/widgets/comment_html.dart';
import '../../ui/widgets/font_scaled_body.dart';
import 'search_controller.dart';
import 'search_dialog.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.params});

  final SearchParams params;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _scrollController = ScrollController();

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

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      ref.read(searchControllerProvider(widget.params).notifier).loadMore();
    }
  }

  Future<void> _openSearch() async {
    final params = await showSearchDialog(context, ref);
    if (params == null || !mounted) return;
    ref.read(lastSearchParamsProvider.notifier).state = params;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SearchScreen(params: params)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider(widget.params));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.params.query),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Изменить поиск',
            onPressed: _openSearch,
          ),
        ],
      ),
      body: FontScaledBody(child: _buildBody(context, state)),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error.toString()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(searchControllerProvider(widget.params).notifier)
                  .reload(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }

    final theme = Theme.of(context);
    final skinExt = theme.extension<SvalkoSkinExt>();
    final dividers = skinExt?.cardDividers ?? false;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: 8,
        left: dividers ? 0 : 8,
        right: dividers ? 0 : 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: state.results.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == state.results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final result = state.results[i];
        final card = _SearchResultCard(result: result);
        if (dividers && i > 0) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [const Divider(height: 1, thickness: 1), card],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: card,
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final d = result.publishedAt;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        '/post',
        arguments: result.isComment
            ? (result.postId, result.commentId)
            : result.postId,
      ),
      child: SkinCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkinHeader(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.author,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: cs.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: result.isComment
                            ? cs.secondaryContainer
                            : cs.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        result.isComment ? 'камент' : 'пост',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: result.isComment
                              ? cs.onSecondaryContainer
                              : cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (result.textHtml.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: CommentHtml(
                  result.textHtml,
                  onSvalkoPost: (id) =>
                      Navigator.of(context).pushNamed('/post', arguments: id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
