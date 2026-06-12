import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/search_result.dart';

class SearchState {
  const SearchState({
    this.results = const [],
    this.totalCount = 0,
    this.skip = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<SearchResult> results;
  final int totalCount;
  final int skip;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final AppError? error;

  SearchState copyWith({
    List<SearchResult>? results,
    int? totalCount,
    int? skip,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    AppError? error,
    bool clearError = false,
  }) =>
      SearchState(
        results: results ?? this.results,
        totalCount: totalCount ?? this.totalCount,
        skip: skip ?? this.skip,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._repo, this._params) : super(const SearchState()) {
    _load();
  }

  final SvalkoRepository _repo;
  final SearchParams _params;

  Future<void> reload() => _load();

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.search(
      query: _params.query,
      order: _params.order,
      searchComments: _params.searchComments,
      skip: state.skip,
    );
    state = switch (result) {
      Ok(:final value) => SearchState(
          results: value.results,
          totalCount: value.totalCount,
          skip: value.results.length,
          hasMore: value.hasMore,
        ),
      Err(:final error) => SearchState(error: error),
    };
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.search(
      query: _params.query,
      order: _params.order,
      searchComments: _params.searchComments,
      skip: state.skip,
    );
    state = switch (result) {
      Ok(:final value) => state.copyWith(
          results: [...state.results, ...value.results],
          totalCount: value.totalCount,
          skip: state.skip + value.results.length,
          hasMore: value.hasMore,
          isLoadingMore: false,
        ),
      Err(:final error) =>
        state.copyWith(isLoadingMore: false, error: error),
    };
  }
}

final searchControllerProvider =
    StateNotifierProvider.family<SearchController, SearchState, SearchParams>(
  (ref, params) => SearchController(ref.watch(repositoryProvider), params),
);

final lastSearchParamsProvider = StateProvider<SearchParams?>((ref) => null);
