import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/parse_guard.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../data/parsers/dark_side_parser.dart';
import '../../data/parsers/feed_parser.dart' show FeedPaginationInfo;
import '../../data/svalko_api.dart';
import '../../models/dark_side_post.dart';
import '../feed/feed_controller.dart' show apiProvider;

class DarkSideFeedState {
  const DarkSideFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage,
    this.maxPage,
    this.hasMore = true,
  });

  final List<DarkSidePost> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final AppError? error;
  final int? currentPage;
  final int? maxPage;
  final bool hasMore;

  DarkSideFeedState copyWith({
    List<DarkSidePost>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    AppError? error,
    int? currentPage,
    int? maxPage,
    bool? hasMore,
    bool clearError = false,
  }) =>
      DarkSideFeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        maxPage: maxPage ?? this.maxPage,
        hasMore: hasMore ?? this.hasMore,
      );
}

class DarkSideFeedController extends StateNotifier<DarkSideFeedState> {
  DarkSideFeedController(this._api) : super(const DarkSideFeedState()) {
    loadInitial();
  }

  final SvalkoApi _api;

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _api.fetchDarkSidePage();
    state = _applyResult(result);
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _api.fetchDarkSidePage();
    state = _applyResult(result, refreshing: true);
  }

  Future<void> loadPage(int page) async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _api.fetchDarkSidePage(page: page);
    state = _applyResult(result);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final nextPage = (state.currentPage ?? 1) - 1;
    if (nextPage < 0) {
      state = state.copyWith(hasMore: false);
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    final result = await _api.fetchDarkSidePage(page: nextPage);
    state = _applyResult(result, appending: true);
  }

  DarkSideFeedState _applyResult(
    Result<String, AppError> result, {
    bool appending = false,
    bool refreshing = false,
  }) {
    switch (result) {
      case Err(:final error):
        return state.copyWith(
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: error,
        );
      case Ok(:final value):
        return _applyParseResult(guardParse(() {
          final parsed = DarkSideParser.parse(value);
          if (parsed.posts.isEmpty && value.contains('author_name')) {
            // Page clearly has post rows, but none parsed — markup likely changed.
            throw StateError('DarkSideParser: 0 posts parsed from a page containing post rows');
          }
          return parsed;
        }), appending: appending);
    }
  }

  DarkSideFeedState _applyParseResult(
    Result<({List<DarkSidePost> posts, FeedPaginationInfo pagination}), AppError> result, {
    required bool appending,
  }) {
    switch (result) {
      case Err():
        return state.copyWith(
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: AppError.parseFailure,
        );
      case Ok(:final value):
        final existing = appending ? state.posts : const <DarkSidePost>[];
        return state.copyWith(
          posts: [...existing, ...value.posts],
          currentPage: value.pagination.currentPage,
          maxPage: value.pagination.maxPage,
          hasMore: value.pagination.currentPage > 0,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          clearError: true,
        );
    }
  }
}

final darkSideFeedControllerProvider =
    StateNotifierProvider<DarkSideFeedController, DarkSideFeedState>((ref) {
  ref.watch(siteModeProvider);
  return DarkSideFeedController(ref.watch(apiProvider));
});
