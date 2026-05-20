import '../parsers/feed_parser.dart';
import '../parsers/post_parser.dart';
import '../svalko_api.dart';
import '../../core/result.dart';
import '../../models/feed_source.dart';
import '../../models/post.dart';
import '../../models/comment.dart';

class FeedPage {
  const FeedPage({required this.posts, required this.pagination});

  final List<Post> posts;
  final FeedPaginationInfo pagination;
}

class PostPage {
  const PostPage({
    required this.post,
    required this.comments,
    required this.pagination,
  });

  final Post post;
  final List<Comment> comments;
  final CommentsPaginationInfo pagination;
}

class SvalkoRepository {
  SvalkoRepository({SvalkoApi? api}) : _api = api ?? SvalkoApi();

  final SvalkoApi _api;

  Future<Result<FeedPage, AppError>> getFeed({
    int? page,
    FeedSource source = const MainFeed(),
  }) async {
    final result = await _api.fetchFeedPage(page: page, source: source);
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseFeed(value),
    };
  }

  Future<Result<PostPage, AppError>> getPost(
    int id, {
    int? commentsPage,
    bool isHistorical = false,
  }) async {
    final result = await _api.fetchPost(
      id,
      commentsPage: commentsPage,
      isHistorical: isHistorical,
    );
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parsePost(value, id),
    };
  }

  Result<FeedPage, AppError> _parseFeed(String html) {
    try {
      final parsed = FeedParser.parse(html);
      return Ok(FeedPage(posts: parsed.posts, pagination: parsed.pagination));
    } catch (_) {
      return const Err(AppError.parseFailure);
    }
  }

  Result<PostPage, AppError> _parsePost(String html, int id) {
    try {
      final parsed = PostParser.parse(html, id);
      if (parsed == null) return const Err(AppError.parseFailure);
      return Ok(PostPage(
        post: parsed.post,
        comments: parsed.comments,
        pagination: parsed.pagination,
      ));
    } catch (_) {
      return const Err(AppError.parseFailure);
    }
  }
}
