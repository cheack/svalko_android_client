import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../data/svalko_api.dart';
import '../../models/ban_page_data.dart';
import '../../models/calendar.dart';
import '../../models/feed_source.dart';
import '../../models/post.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in main.dart with a cache-enabled instance.
final apiProvider = Provider<SvalkoApi>((_) => SvalkoApi());

/// Currently active tag name shown in the drawer, null when not in a tag feed.
final activeTagProvider = StateProvider<String?>((ref) => null);

/// Persists drawer tags list scroll offset across open/close.
final drawerTagsScrollOffsetProvider = StateProvider<double>((ref) => 0);

/// Last-viewed month in the calendar sheet + last selected day path.
final calendarStateProvider = StateProvider<({CalendarMonth? month, String? selectedPath})>(
  (ref) => (month: null, selectedPath: null),
);

void navigateToDateFeed(BuildContext context, WidgetRef ref, DateTime dt) {
  final feed = DateFeed.fromDateTime(dt);
  ref.read(calendarStateProvider.notifier).update(
        (s) => (month: s.month, selectedPath: feed.path),
      );
  Navigator.of(context).pushNamed('/date', arguments: feed);
}

final repositoryProvider = Provider<SvalkoRepository>(
  (ref) => SvalkoRepository(
    api: ref.watch(apiProvider),
    calendarBox: ref.watch(calendarBoxProvider),
  ),
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
    this.calendar,
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
  final CalendarMonth? calendar;

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
    CalendarMonth? calendar,
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
        calendar: calendar ?? this.calendar,
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
    int? existingMaxPage,
    CalendarMonth? existingCalendar,
  }) {
    final newMax = value.pagination.maxPage;
    return FeedState(
      posts: [...existingPosts, ...value.posts],
      currentPage: value.pagination.currentPage,
      maxPage: (existingMaxPage != null && existingMaxPage > newMax)
          ? existingMaxPage
          : newMax,
      hasMore: value.pagination.currentPage > 0,
      pageFirstIndex: {
        ...existingPageIndex,
        value.pagination.currentPage: existingPosts.length,
      },
      calendar: value.calendar ?? existingCalendar,
    );
  }

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
    final prevMaxPage = state.maxPage;
    state = state.copyWith(isRefreshing: true, clearError: true, clearBanData: true);
    final result = await _repo.getFeed(page: page, source: _source);
    state = switch (result) {
      FeedSuccess(:final page) => _stateFromFeedPage(page, existingMaxPage: prevMaxPage),
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
          existingMaxPage: state.maxPage,
          existingCalendar: state.calendar,
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
  (ref, source) {
    ref.watch(siteModeProvider);
    return FeedController(ref.watch(repositoryProvider), source);
  },
);
