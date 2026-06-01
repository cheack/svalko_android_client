import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:hive_ce_flutter/hive_flutter.dart' show Box;
import 'package:html/parser.dart' as html_parser;
import '../parsers/ban_page_parser.dart';
import '../parsers/calendar_parser.dart';
import '../parsers/feed_parser.dart';
import '../parsers/images_parser.dart';
import '../parsers/post_parser.dart';
import '../parsers/tags_parser.dart';
import '../svalko_api.dart';
import '../../core/result.dart';
import '../../models/ban_page_data.dart';
import '../../models/calendar.dart';
import '../../models/feed_source.dart';
import '../../models/image_item.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
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
      try {
        return FeedBanned(BanPageParser.parse(html));
      } catch (_) {
        return const FeedFailure(AppError.parseFailure);
      }
    }
    try {
      final parsed = FeedParser.parse(html);
      if (parsed.calendar != null) _currentMonthCache ??= parsed.calendar;
      return FeedSuccess(FeedPage(
        posts: parsed.posts,
        pagination: parsed.pagination,
        calendar: parsed.calendar,
      ));
    } catch (_) {
      return const FeedFailure(AppError.parseFailure);
    }
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
    try {
      final doc = html_parser.parse(html);
      final calendar = CalendarParser.parse(doc);
      final month = calendar ?? () {
        final m = RegExp(r'/(\d{4})/(\d+)/').firstMatch(path);
        if (m == null) return null;
        return CalendarParser.emptyMonth(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
        );
      }();
      if (month == null) return const Err(AppError.parseFailure);
      if (isCurrentMonth) {
        _currentMonthCache = month;
      } else {
        _calendarBox?.put(path, _encodeCalendar(month));
      }
      return Ok(month);
    } catch (_) {
      return const Err(AppError.parseFailure);
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
