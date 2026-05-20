import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_logger.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../core/result.dart';
import '../feed/feed_controller.dart';

// ---------------------------------------------------------------------------
// Post state
// ---------------------------------------------------------------------------

class PostState {
  const PostState({
    this.post,
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 0,
    this.totalPages = 1,
    this.totalComments = 0,
  });

  final Post? post;
  final List<Comment> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final AppError? error;
  final int currentPage;
  final int totalPages;
  final int totalComments;

  bool get hasMore => currentPage < totalPages - 1;

  PostState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? isLoading,
    bool? isLoadingMore,
    AppError? error,
    int? currentPage,
    int? totalPages,
    int? totalComments,
    bool clearError = false,
  }) =>
      PostState(
        post: post ?? this.post,
        comments: comments ?? this.comments,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        totalComments: totalComments ?? this.totalComments,
      );
}

// ---------------------------------------------------------------------------
// Post controller
// ---------------------------------------------------------------------------

class PostController extends StateNotifier<PostState> {
  PostController(this._repo, this._postId) : super(const PostState()) {
    load();
  }

  final SvalkoRepository _repo;
  final int _postId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getPost(_postId);
    state = switch (result) {
      Ok(:final value) => PostState(
          post: value.post,
          comments: value.comments,
          currentPage: value.pagination.currentPage,
          totalPages: value.pagination.totalPages,
          totalComments: value.pagination.totalComments,
        ),
      Err(:final error) => PostState(error: error),
    };
  }

  Future<void> loadPage(int page) async {
    if (state.isLoadingMore) return;
    AppLogger.instance.info(
      'loadPage($page) start, currentPage=${state.currentPage}',
    );
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.getPost(
      _postId,
      commentsPage: page,
      isHistorical: page < state.totalPages - 1,
    );
    switch (result) {
      case Ok(:final value):
        AppLogger.instance.info(
          'loadPage($page) done, comments=${value.comments.length},'
          ' parsed currentPage=${value.pagination.currentPage}',
        );
        state = state.copyWith(
          comments: value.comments,
          currentPage: page,
          totalPages: value.pagination.totalPages,
          totalComments: value.pagination.totalComments,
          isLoadingMore: false,
        );
      case Err(:final error):
        AppLogger.instance.error('loadPage($page) error: $error');
        state = state.copyWith(isLoadingMore: false, error: error);
    }
  }
}

final postControllerProvider = StateNotifierProvider.family<PostController,
    PostState, int>((ref, postId) {
  return PostController(ref.watch(repositoryProvider), postId);
});
