import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../data/svalko_api.dart';
import '../../models/feed_source.dart';
import '../../models/post.dart';
import '../../core/result.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in main.dart with a cache-enabled instance.
final apiProvider = Provider<SvalkoApi>((_) => SvalkoApi());

final repositoryProvider = Provider<SvalkoRepository>(
  (ref) => SvalkoRepository(api: ref.watch(apiProvider)),
);

// ---------------------------------------------------------------------------
// Feed state
// ---------------------------------------------------------------------------

class FeedState {
  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage,
    this.maxPage,
    this.hasMore = true,
    this.pageFirstIndex = const {},
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final AppError? error;
  final int? currentPage;
  final int? maxPage;
  final bool hasMore;
  /// Maps page number → index of its first post in [posts].
  final Map<int, int> pageFirstIndex;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    AppError? error,
    int? currentPage,
    int? maxPage,
    bool? hasMore,
    Map<int, int>? pageFirstIndex,
    bool clearError = false,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        maxPage: maxPage ?? this.maxPage,
        hasMore: hasMore ?? this.hasMore,
        pageFirstIndex: pageFirstIndex ?? this.pageFirstIndex,
      );
}

// ---------------------------------------------------------------------------
// Feed controller
// ---------------------------------------------------------------------------

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repo, this._source) : super(const FeedState()) {
    loadInitial();
  }

  final SvalkoRepository _repo;
  final FeedSource _source;

  FeedState _stateFromFeedPage(
    FeedPage value, {
    List<Post> existingPosts = const [],
    Map<int, int> existingPageIndex = const {},
  }) =>
      FeedState(
        posts: [...existingPosts, ...value.posts],
        currentPage: value.pagination.currentPage,
        maxPage: value.pagination.maxPage,
        hasMore: value.pagination.currentPage > 0,
        pageFirstIndex: {
          ...existingPageIndex,
          value.pagination.currentPage: existingPosts.length,
        },
      );

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getFeed(source: _source);
    state = switch (result) {
      Ok(:final value) => _stateFromFeedPage(value),
      Err(:final error) => FeedState(error: error),
    };
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _repo.getFeed(source: _source);
    state = switch (result) {
      Ok(:final value) => _stateFromFeedPage(value),
      Err(:final error) => state.copyWith(isRefreshing: false, error: error),
    };
  }

  Future<void> loadPage(int page) async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final result = await _repo.getFeed(page: page, source: _source);
    state = switch (result) {
      Ok(:final value) => _stateFromFeedPage(value),
      Err(:final error) => state.copyWith(isRefreshing: false, error: error),
    };
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final nextPage = (state.currentPage ?? 1) - 1;
    if (nextPage < 0) {
      state = state.copyWith(hasMore: false);
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.getFeed(page: nextPage, source: _source);
    state = switch (result) {
      Ok(:final value) => _stateFromFeedPage(
          value,
          existingPosts: state.posts,
          existingPageIndex: state.pageFirstIndex,
        ).copyWith(isLoadingMore: false),
      Err(:final error) => state.copyWith(isLoadingMore: false, error: error),
    };
  }
}

final feedControllerProvider =
    StateNotifierProvider.family<FeedController, FeedState, FeedSource>(
  (ref, source) => FeedController(ref.watch(repositoryProvider), source),
);
