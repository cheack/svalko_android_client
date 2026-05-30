import '../parsers/ban_page_parser.dart';
import '../parsers/feed_parser.dart';
import '../parsers/images_parser.dart';
import '../parsers/post_parser.dart';
import '../parsers/tags_parser.dart';
import '../svalko_api.dart';
import '../../core/result.dart';
import '../../models/ban_page_data.dart';
import '../../models/feed_source.dart';
import '../../models/image_item.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../models/tag.dart';

class FeedPage {
  const FeedPage({required this.posts, required this.pagination});

  final List<Post> posts;
  final FeedPaginationInfo pagination;
}

sealed class FeedResult {
  const FeedResult();
}

class FeedSuccess extends FeedResult {
  const FeedSuccess(this.page);
  final FeedPage page;
}

class FeedBanned extends FeedResult {
  const FeedBanned(this.data);
  final BanPageData data;
}

class FeedFailure extends FeedResult {
  const FeedFailure(this.error);
  final AppError error;
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

  Future<FeedResult> getFeed({
    int? page,
    FeedSource source = const MainFeed(),
  }) async {
    final result = await _api.fetchFeedPage(page: page, source: source);
    return switch (result) {
      Err(:final error) => FeedFailure(error),
      Ok(:final value) => _parseFeedResult(value),
    };
  }

  Future<FeedResult> submitBanAnswer({
    required int riddleId,
    required String answer,
  }) async {
    final result = await _api.submitBanAnswer(
      riddleId: riddleId,
      answer: answer,
    );
    return switch (result) {
      Err(:final error) => FeedFailure(error),
      Ok(:final value) => _parseFeedResult(value),
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

  FeedResult _parseFeedResult(String html) {
    if (BanPageParser.isBanPage(html)) {
      try {
        return FeedBanned(BanPageParser.parse(html));
      } catch (_) {
        return const FeedFailure(AppError.parseFailure);
      }
    }
    try {
      final parsed = FeedParser.parse(html);
      return FeedSuccess(FeedPage(posts: parsed.posts, pagination: parsed.pagination));
    } catch (_) {
      return const FeedFailure(AppError.parseFailure);
    }
  }

  Future<Result<int, AppError>> getRandomPostId() =>
      _api.fetchRandomPostId();

  Future<Result<List<ImageItem>, AppError>> getImages() async {
    final result = await _api.fetchImagesPage();
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseImages(value),
    };
  }

  Future<Result<(int, int?), AppError>> getImagePostId(String filename) =>
      _api.fetchImagePostId(filename);

  Result<List<ImageItem>, AppError> _parseImages(String html) {
    try {
      return Ok(ImagesParser.parse(html));
    } catch (_) {
      return const Err(AppError.parseFailure);
    }
  }

  Future<Result<List<Tag>, AppError>> getTags() async {
    final result = await _api.fetchTagsPage();
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseTags(value),
    };
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

  Future<Result<String, AppError>> vote(int postId, int vote) =>
      _api.vote(postId, vote);

  Future<Result<String, AppError>> boroda(int postId, int dbl) =>
      _api.boroda(postId, dbl);

  Result<List<Tag>, AppError> _parseTags(String html) {
    try {
      return Ok(TagsParser.parse(html));
    } catch (_) {
      return const Err(AppError.parseFailure);
    }
  }
}
