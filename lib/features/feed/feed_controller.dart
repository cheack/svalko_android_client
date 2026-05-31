import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../data/svalko_api.dart';
import '../../models/ban_page_data.dart';
import '../../models/feed_source.dart';
import '../../models/post.dart';
import '../../core/result.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in main.dart with a cache-enabled instance.
final apiProvider = Provider<SvalkoApi>((_) => SvalkoApi());

/// Currently active tag name shown in the drawer, null when not in a tag feed.
final activeTagProvider = StateProvider<String?>((ref) => null);

/// Persists drawer tags list scroll offset across open/close.
final drawerTagsScrollOffsetProvider = StateProvider<double>((ref) => 0);

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
    this.banData,
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
  final BanPageData? banData;
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
    BanPageData? banData,
    int? currentPage,
    int? maxPage,
    bool? hasMore,
    Map<int, int>? pageFirstIndex,
    bool clearError = false,
    bool clearBanData = false,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        banData: clearBanData ? null : (banData ?? this.banData),
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

  FeedState _stateFromResult(FeedResult result) => switch (result) {
        FeedSuccess(:final page) => _stateFromFeedPage(page),
        FeedBanned(:final data) => FeedState(banData: data),
        FeedFailure(:final error) => FeedState(error: error),
      };

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true, clearBanData: true);
    final result = await _repo.getFeed(source: _source);
    state = _stateFromResult(result);
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true, clearBanData: true);
    final result = await _repo.getFeed(source: _source);
    state = switch (result) {
      FeedSuccess(:final page) => _stateFromFeedPage(page),
      FeedBanned(:final data) => FeedState(banData: data),
      FeedFailure(:final error) => state.copyWith(isRefreshing: false, error: error),
    };
  }

  Future<void> loadPage(int page) async {
    state = state.copyWith(isRefreshing: true, clearError: true, clearBanData: true);
    final result = await _repo.getFeed(page: page, source: _source);
    state = switch (result) {
      FeedSuccess(:final page) => _stateFromFeedPage(page),
      FeedBanned(:final data) => FeedState(banData: data),
      FeedFailure(:final error) => state.copyWith(isRefreshing: false, error: error),
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
      FeedSuccess(:final page) => _stateFromFeedPage(
          page,
          existingPosts: state.posts,
          existingPageIndex: state.pageFirstIndex,
        ).copyWith(isLoadingMore: false),
      FeedBanned(:final data) => FeedState(banData: data),
      FeedFailure(:final error) => state.copyWith(isLoadingMore: false, error: error),
    };
  }

  Future<void> submitBanAnswer(int riddleId, String answer) async {
    state = state.copyWith(isLoading: true, clearBanData: true);

    const maxAttempts = 4;
    const retryDelay = Duration(seconds: 2);

    var result = await _repo.submitBanAnswer(
      riddleId: riddleId,
      answer: answer,
    );

    for (var attempt = 1; attempt < maxAttempts; attempt++) {
      if (result is! FeedFailure) break;
      final error = result.error;
      if (error != AppError.network && error != AppError.timeout) break;
      await Future.delayed(retryDelay);
      result = await _repo.submitBanAnswer(riddleId: riddleId, answer: answer);
    }

    state = _stateFromResult(result);
  }
}

final feedControllerProvider =
    StateNotifierProvider.family<FeedController, FeedState, FeedSource>(
  (ref, source) => FeedController(ref.watch(repositoryProvider), source),
);
