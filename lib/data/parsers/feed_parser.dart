import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/app_logger.dart';
import '../../core/config.dart';
import '../../models/author.dart';
import '../../models/post.dart';
import '../../models/tag.dart';
import 'text_extractor.dart';

class FeedPaginationInfo {
  const FeedPaginationInfo({required this.currentPage, required this.maxPage});

  final int currentPage;
  final int maxPage;
}

class FeedParseResult {
  const FeedParseResult({required this.posts, required this.pagination});

  final List<Post> posts;
  final FeedPaginationInfo pagination;
}

abstract final class FeedParser {
  static FeedParseResult parse(String htmlContent) {
    final doc = html_parser.parse(htmlContent);
    final posts = _parsePosts(doc);
    final pagination = _parsePagination(doc);
    return FeedParseResult(posts: posts, pagination: pagination);
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

    final author = _parseAuthor(el);
    if (author == null) return null;

    final publishedAt = _parseDate(el);
    if (publishedAt == null) return null;

    final rating = _parseRating(el, id);
    final approvedBy = _parseApprovedBy(el);
    final imageUrls = _parseImageUrls(el);
    final videoUrls = _parseVideoUrls(el);
    final externalLinks = _parseExternalLinks(el);
    final tags = _parseTags(el);
    final commentCount = _parseCommentCount(el);
    final text = _parseText(el);

    AppLogger.instance.info(
      'post $id: ${imageUrls.length} img, ${videoUrls.length} vid',
    );
    return Post(
      id: id,
      author: author,
      publishedAt: publishedAt,
      text: text,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      externalLinks: externalLinks,
      tags: tags,
      rating: rating,
      commentCount: commentCount,
      approvedBy: approvedBy,
    );
  }

  static Author? _parseAuthor(Element el) {
    final a = el.querySelector('.info .author a');
    if (a == null) return null;
    final name = a.text.trim();
    final href = a.attributes['href'] ?? '';
    final profileUrl = href.startsWith('http')
        ? href
        : '${Config.baseUrl}/$href';
    return Author(name: name, profileUrl: profileUrl);
  }

  static DateTime? _parseDate(Element el) {
    final infoEl = el.querySelector('.info');
    if (infoEl == null) return null;
    // Date is a raw text node after the author span — walk text nodes
    for (final node in infoEl.nodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        final text = node.text?.trim() ?? '';
        final dt = _tryParseDateTime(text);
        if (dt != null) return dt;
      }
    }
    return null;
  }

  static DateTime? _tryParseDateTime(String s) {
    // Format: "2026-05-10 18:53:28"
    final clean = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    try {
      return DateTime.parse(clean.substring(0, 19));
    } catch (_) {
      return null;
    }
  }

  static PostRating? _parseRating(Element el, int id) {
    final span = el.querySelector('#rating_span_$id');
    if (span == null) return null;
    // Format: "+26|0|-1 = +96%"
    final match = RegExp(r'([+-]?\d+)\|(\d+)\|([+-]?\d+)\s*=\s*([+-]?\d+)%')
        .firstMatch(span.text);
    if (match == null) return null;
    return PostRating(
      plus: int.parse(match.group(1)!),
      neutral: int.parse(match.group(2)!),
      minus: int.parse(match.group(3)!),
      percentage: int.parse(match.group(4)!),
    );
  }

  static String? _parseApprovedBy(Element el) {
    final small = el.querySelector('.info small a');
    return small?.text.trim();
  }

  static List<String> _parseImageUrls(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return const [];
    return textDiv
        .querySelectorAll('img')
        .map((img) => _resolveUrl(img.attributes['src'] ?? ''))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  static List<String> _parseVideoUrls(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return const [];
    return textDiv
        .querySelectorAll('video source[src]')
        .map((s) => _resolveUrl(s.attributes['src'] ?? ''))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  static List<String> _parseExternalLinks(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return const [];
    return textDiv
        .querySelectorAll('a[href]')
        .map((a) => a.attributes['href'] ?? '')
        .where((h) => h.startsWith('http'))
        .toList();
  }

  static List<Tag> _parseTags(Element el) {
    return el.querySelectorAll('.tags a[href]').expand((a) {
      final href = a.attributes['href'] ?? '';
      final idMatch = RegExp(r'/tag/(\d+)').firstMatch(href);
      if (idMatch == null) return const <Tag>[];
      final id = int.tryParse(idMatch.group(1) ?? '') ?? 0;
      return [Tag(id: id, name: a.text.trim())];
    }).toList();
  }

  static int _parseCommentCount(Element el) {
    final a = el.querySelector('.manage a.read span');
    return int.tryParse(a?.text.trim() ?? '') ?? 0;
  }

  static String? _parseText(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return null;
    // Extract text, excluding the nested .tags div
    final clone = textDiv.clone(true);
    clone.querySelector('.tags')?.remove();
    final raw = extractText(clone);
    return raw.isEmpty ? null : raw;
  }

  static FeedPaginationInfo _parsePagination(Document doc) {
    final paging = doc.querySelector('div.paging');
    if (paging == null) return const FeedPaginationInfo(currentPage: 0, maxPage: 0);

    // Current page is in <b>[N]</b>
    final currentMatch = RegExp(r'\[(\d+)\]').firstMatch(paging.querySelector('b')?.text ?? '');
    final current = int.tryParse(currentMatch?.group(1) ?? '') ?? 0;

    // Max page is the bold (current) when on homepage, or largest link number
    final allNums = RegExp(r'\[(\d+)\]')
        .allMatches(paging.text)
        .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
        .toList();
    final maxPage = allNums.isEmpty ? 0 : allNums.reduce((a, b) => a > b ? a : b);

    return FeedPaginationInfo(currentPage: current, maxPage: maxPage);
  }

  static String _resolveUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return '${Config.baseUrl}/$url';
  }
}
