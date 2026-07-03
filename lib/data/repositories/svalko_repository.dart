import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:hive_ce_flutter/hive_flutter.dart' show Box;
import 'package:html/parser.dart' as html_parser;
import '../parsers/ban_page_parser.dart';
import '../parsers/calendar_parser.dart';
import '../parsers/feed_parser.dart';
import '../parsers/images_parser.dart';
import '../parsers/post_parser.dart';
import '../parsers/last_parser.dart';
import '../parsers/search_parser.dart';
import '../parsers/tags_parser.dart';
import '../svalko_api.dart';
import '../../core/parse_guard.dart';
import '../../core/result.dart';
import '../../models/ban_page_data.dart';
import '../../models/calendar.dart';
import '../../models/feed_source.dart';
import '../../models/image_item.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../models/last_item.dart';
import '../../models/tag.dart';

class FeedPage {
  const FeedPage({required this.posts, required this.pagination, this.calendar});

  final List<Post> posts;
  final FeedPaginationInfo pagination;
  final CalendarMonth? calendar;
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
  SvalkoRepository({SvalkoApi? api, Box<String>? calendarBox})
      : _api = api ?? SvalkoApi(),
        _calendarBox = calendarBox;

  final SvalkoApi _api;
  final Box<String>? _calendarBox;
  CalendarMonth? _currentMonthCache;

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
      return switch (guardParse(() => BanPageParser.parse(html))) {
        Ok(:final value) => FeedBanned(value),
        Err(:final error) => FeedFailure(error),
      };
    }
    return switch (guardParse(() => FeedParser.parse(html))) {
      Ok(:final value) => () {
          if (value.calendar != null) _currentMonthCache ??= value.calendar;
          return FeedSuccess(FeedPage(
            posts: value.posts,
            pagination: value.pagination,
            calendar: value.calendar,
          ));
        }(),
      Err(:final error) => FeedFailure(error),
    };
  }

  CalendarMonth? getCachedCalendar(String path) {
    final now = DateTime.now();
    if (path == CalendarParser.monthPath(now.year, now.month)) {
      return _currentMonthCache;
    }
    final raw = _calendarBox?.get(path);
    if (raw != null) {
      try { return _decodeCalendar(raw); } catch (_) {}
    }
    return null;
  }

  Future<Result<CalendarMonth, AppError>> getCalendar(String path) async {
    final now = DateTime.now();
    final currentPath = CalendarParser.monthPath(now.year, now.month);
    final isCurrentMonth = path == currentPath;

    if (isCurrentMonth) {
      if (_currentMonthCache != null) return Ok(_currentMonthCache!);
    } else {
      final cached = _calendarBox?.get(path);
      if (cached != null) {
        try { return Ok(_decodeCalendar(cached)); } catch (_) {}
      }
    }

    final result = await _api.fetchPath(path);
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseCalendar(value, path, isCurrentMonth: isCurrentMonth),
    };
  }

  Result<CalendarMonth, AppError> _parseCalendar(String html, String path, {bool isCurrentMonth = false}) {
    final result = guardParse<CalendarMonth?>(() {
      final doc = html_parser.parse(html);
      final calendar = CalendarParser.parse(doc);
      if (calendar != null) return calendar;
      final m = RegExp(r'/(\d{4})/(\d+)/').firstMatch(path);
      if (m == null) return null;
      return CalendarParser.emptyMonth(int.parse(m.group(1)!), int.parse(m.group(2)!));
    });
    switch (result) {
      case Err(:final error):
        return Err(error);
      case Ok(value: null):
        return const Err(AppError.parseFailure);
      case Ok(:final value):
        final month = value!;
        if (isCurrentMonth) {
          _currentMonthCache = month;
        } else {
          _calendarBox?.put(path, _encodeCalendar(month));
        }
        return Ok(month);
    }
  }

  static String _encodeCalendar(CalendarMonth c) => jsonEncode({
        'y': c.year,
        'm': c.month,
        'p': c.prevPath,
        'n': c.nextPath,
        'd': c.days.map((d) => [d.day, d.isCurrentMonth ? 1 : 0, d.path]).toList(),
      });

  static CalendarMonth _decodeCalendar(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return CalendarMonth(
      year: j['y'] as int,
      month: j['m'] as int,
      prevPath: j['p'] as String?,
      nextPath: j['n'] as String?,
      days: (j['d'] as List)
          .map((d) => CalendarDay(
                day: d[0] as int,
                isCurrentMonth: d[1] == 1,
                isToday: false,
                path: d[2] as String?,
              ))
          .toList(),
    );
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

  Result<List<ImageItem>, AppError> _parseImages(String html) =>
      guardParse(() => ImagesParser.parse(html));

  Future<Result<(List<LastComment>, List<LastImage>), AppError>> getLast({int skip = 0}) async {
    final result = await _api.fetchLastPage(skip: skip);
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseLast(value),
    };
  }

  Result<(List<LastComment>, List<LastImage>), AppError> _parseLast(String html) =>
      guardParse(() => LastParser.parse(html));

  Future<Result<List<Tag>, AppError>> getTags() async {
    final result = await _api.fetchTagsPage();
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseTags(value),
    };
  }

  Result<PostPage, AppError> _parsePost(String html, int id) {
    final result = guardParse(() => PostParser.parse(html, id));
    return switch (result) {
      Ok(value: final parsed?) => Ok(PostPage(
          post: parsed.post,
          comments: parsed.comments,
          pagination: parsed.pagination,
        )),
      Ok() => const Err(AppError.parseFailure),
      Err(:final error) => Err(error),
    };
  }

  Future<Result<SearchParseResult, AppError>> search({
    required String query,
    String order = 'rel',
    bool searchComments = true,
    int skip = 0,
  }) async {
    final result = await _api.fetchSearchPage(
      query: query,
      order: order,
      searchComments: searchComments,
      skip: skip,
    );
    return switch (result) {
      Err(:final error) => Err(error),
      Ok(:final value) => _parseSearch(value),
    };
  }

  Result<SearchParseResult, AppError> _parseSearch(String html) =>
      guardParse(() => SearchParser.parse(html));

  Future<Result<String, AppError>> vote(int postId, int vote) =>
      _api.vote(postId, vote);

  Future<Result<String, AppError>> boroda(int postId, int dbl) =>
      _api.boroda(postId, dbl);

  Result<List<Tag>, AppError> _parseTags(String html) =>
      guardParse(() => TagsParser.parse(html));
}
