import 'package:html/dom.dart' hide Comment;
import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/author.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../models/tag.dart';
import 'text_extractor.dart';

class CommentsPaginationInfo {
  const CommentsPaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
  });

  final int currentPage;
  final int totalPages;
  final int totalComments;
}

class PostParseResult {
  const PostParseResult({
    required this.post,
    required this.comments,
    required this.pagination,
  });

  final Post post;
  final List<Comment> comments;
  final CommentsPaginationInfo pagination;
}

abstract final class PostParser {
  static PostParseResult? parse(String htmlContent, int postId) {
    final doc = html_parser.parse(htmlContent);
    final post = _parsePost(doc, postId);
    if (post == null) return null;
    final comments = _parseComments(doc, postId);
    var pagination = _parseCommentsPagination(doc);
    // No pagination block means all comments fit on one page — count them directly
    if (pagination.totalComments == 0 && pagination.totalPages == 1) {
      pagination = CommentsPaginationInfo(
        currentPage: 0,
        totalPages: 1,
        totalComments: comments.length,
      );
    }
    return PostParseResult(post: post, comments: comments, pagination: pagination);
  }

  static Post? _parsePost(Document doc, int postId) {
    // On a post page the post block uses class "single"
    final el = doc.querySelector('div.single');
    if (el == null) return null;

    final author = _parseAuthor(el);
    if (author == null) return null;

    final publishedAt = _parseDate(el);
    if (publishedAt == null) return null;

    final rating = _parseRating(el, postId);
    final approvedBy = _parseApprovedBy(el);
    final imageUrls = _parseImageUrls(el);
    final videoUrls = _parseVideoUrls(el);
    final externalLinks = _parseExternalLinks(el);
    final tags = _parseTags(el);
    final text = _parseText(el);

    return Post(
      id: postId,
      author: author,
      publishedAt: publishedAt,
      text: text,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      externalLinks: externalLinks,
      tags: tags,
      rating: rating,
      commentCount: 0, // not shown on post page itself
      approvedBy: approvedBy,
    );
  }

  static List<Comment> _parseComments(Document doc, int postId) {
    final elements = doc.querySelectorAll('div.comment');
    final result = <Comment>[];
    for (final el in elements) {
      try {
        final comment = _parseCommentElement(el, postId);
        if (comment != null) result.add(comment);
      } catch (_) {
        // skip broken comment
      }
    }
    return result;
  }

  static Comment? _parseCommentElement(Element el, int postId) {
    final anchor = el.querySelector('a[name]');
    final anchorName = anchor?.attributes['name'] ?? '';
    if (!anchorName.startsWith('c')) return null;
    // "c" alone is a pagination marker — skip it
    final idStr = anchorName.substring(1);
    if (idStr.isEmpty) return null;
    final id = int.tryParse(idStr);
    if (id == null) return null;

    final author = _parseAuthor(el);
    if (author == null) return null;

    final publishedAt = _parseDate(el);
    if (publishedAt == null) return null;

    final imageUrls = _parseImageUrls(el);
    final videoUrls = _parseVideoUrls(el);
    final text = _parseText(el);

    return Comment(
      id: id,
      postId: postId,
      author: author,
      publishedAt: publishedAt,
      text: text,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
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
    return el.querySelector('.info small a')?.text.trim();
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
    return el.querySelectorAll('.tags a[href]').map((a) {
      final href = a.attributes['href'] ?? '';
      final idMatch = RegExp(r'/tag/(\d+)').firstMatch(href);
      final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
      return Tag(id: id, name: a.text.trim());
    }).toList();
  }

  static String? _parseText(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return null;
    final clone = textDiv.clone(true);
    clone.querySelector('.tags')?.remove();
    final raw = extractText(clone);
    return raw.isEmpty ? null : raw;
  }

  static CommentsPaginationInfo _parseCommentsPagination(Document doc) {
    // The pagination comment block: <div class="comment"> with <a name="c">
    // Text: "насрано N раз:" followed by page links [0][1]...[N] with current in <b>
    final metaComment = doc.querySelectorAll('div.comment').where((el) {
      final anchor = el.querySelector('a[name]');
      return anchor?.attributes['name'] == 'c';
    }).firstOrNull;

    if (metaComment == null) {
      return const CommentsPaginationInfo(
          currentPage: 0, totalPages: 1, totalComments: 0);
    }

    final text = metaComment.querySelector('.text')?.text ?? '';

    final totalMatch = RegExp(r'насрано\s+(\d+)\s+раз').firstMatch(text);
    final total = int.tryParse(totalMatch?.group(1) ?? '') ?? 0;

    // Count page links — both <a href> and <b> (current page)
    final pageLinks = metaComment.querySelectorAll('.text a[href]').length;
    final hasBold = metaComment.querySelector('.text b') != null;
    final totalPages = pageLinks + (hasBold ? 1 : 0);

    final currentBold = metaComment.querySelector('.text b')?.text ?? '';
    final currentMatch = RegExp(r'\[(\d+)\]').firstMatch(currentBold);
    final current = int.tryParse(currentMatch?.group(1) ?? '') ?? 0;

    return CommentsPaginationInfo(
      currentPage: current,
      totalPages: totalPages == 0 ? 1 : totalPages,
      totalComments: total,
    );
  }

  static String _resolveUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return '${Config.baseUrl}/$url';
  }
}
