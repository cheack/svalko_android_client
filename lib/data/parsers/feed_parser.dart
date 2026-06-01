import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/app_logger.dart';
import '../../models/calendar.dart';
import '../../models/post.dart';
import 'calendar_parser.dart';
import 'post_element_helpers.dart';

class FeedPaginationInfo {
  const FeedPaginationInfo({required this.currentPage, required this.maxPage});

  final int currentPage;
  final int maxPage;
}

class FeedParseResult {
  const FeedParseResult({
    required this.posts,
    required this.pagination,
    this.calendar,
  });

  final List<Post> posts;
  final FeedPaginationInfo pagination;
  final CalendarMonth? calendar;
}

abstract final class FeedParser {
  static FeedParseResult parse(String htmlContent) {
    final doc = html_parser.parse(htmlContent);
    final posts = _parsePosts(doc);
    final pagination = _parsePagination(doc);
    final calendar = CalendarParser.parse(doc);
    return FeedParseResult(posts: posts, pagination: pagination, calendar: calendar);
  }

  static List<Post> _parsePosts(Document doc) {
    final elements = doc.querySelectorAll('div.posting');
    final result = <Post>[];
    for (final el in elements) {
      try {
        final post = _parsePostElement(el);
        if (post != null) result.add(post);
      } catch (e) {
        // skip broken post, keep parsing the rest
      }
    }
    return result;
  }

  static Post? _parsePostElement(Element el) {
    final anchor = el.querySelector('a[name]');
    final anchorName = anchor?.attributes['name'] ?? '';
    if (!anchorName.startsWith('a')) return null;
    final id = int.tryParse(anchorName.substring(1));
    if (id == null) return null;

    final author = parseAuthor(el);
    if (author == null) return null;

    final publishedAt = parseDate(el);
    if (publishedAt == null) return null;

    final rating = parseRating(el, id);
    final borodaCount = parseBorodaCount(el, id);
    final approvedBy = parseApprovedBy(el);
    final imageUrls = parseImageUrls(el);
    final videoUrls = parseVideoUrls(el);
    final externalLinks = parseExternalLinks(el);
    final tags = parseTags(el);
    final commentCount = _parseCommentCount(el);
    final text = parseText(el);
    final textHtml = parsePostHtml(el);
    final voteState = parseVoteState(el, id);
    final availableVotes = parseAvailableVotes(el, id);

    AppLogger.instance.info(
      'post $id: ${imageUrls.length} img, ${videoUrls.length} vid',
    );
    return Post(
      id: id,
      author: author,
      publishedAt: publishedAt,
      text: text,
      textHtml: textHtml,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      externalLinks: externalLinks,
      tags: tags,
      rating: rating,
      borodaCount: borodaCount,
      commentCount: commentCount,
      approvedBy: approvedBy,
      parsedVote: voteState.vote,
      parsedBoroda: voteState.boroda,
      availableVotes: availableVotes.isEmpty ? null : availableVotes,
    );
  }

  static int _parseCommentCount(Element el) {
    final a = el.querySelector('.manage a.read span');
    return int.tryParse(a?.text.trim() ?? '') ?? 0;
  }

  static FeedPaginationInfo _parsePagination(Document doc) {
    final paging = doc.querySelector('div.paging');
    if (paging == null) return const FeedPaginationInfo(currentPage: 0, maxPage: 0);

    final currentMatch = RegExp(r'\[(\d+)\]').firstMatch(paging.querySelector('b')?.text ?? '');
    final current = int.tryParse(currentMatch?.group(1) ?? '') ?? 0;

    final allNums = RegExp(r'\[(\d+)\]')
        .allMatches(paging.text)
        .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
        .toList();
    final maxPage = allNums.isEmpty ? 0 : allNums.reduce((a, b) => a > b ? a : b);

    return FeedPaginationInfo(currentPage: current, maxPage: maxPage);
  }
}
