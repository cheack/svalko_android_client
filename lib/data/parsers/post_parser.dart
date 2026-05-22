import 'package:html/dom.dart' hide Comment;
import 'package:html/parser.dart' as html_parser;
import '../../models/comment.dart';
import '../../models/post.dart';
import 'post_element_helpers.dart';

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
    final el = doc.querySelector('div.single');
    if (el == null) return null;

    final author = parseAuthor(el);
    if (author == null) return null;

    final publishedAt = parseDate(el);
    if (publishedAt == null) return null;

    final rating = parseRating(el, postId);
    final borodaCount = parseBorodaCount(el, postId);
    final approvedBy = parseApprovedBy(el);
    final imageUrls = parseImageUrls(el);
    final videoUrls = parseVideoUrls(el);
    final externalLinks = parseExternalLinks(el);
    final tags = parseTags(el);
    final text = parseText(el);
    final textHtml = parsePostHtml(el);

    return Post(
      id: postId,
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
      commentCount: 0,
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
    final idStr = anchorName.substring(1);
    if (idStr.isEmpty) return null;
    final id = int.tryParse(idStr);
    if (id == null) return null;

    final author = parseAuthor(el);
    if (author == null) return null;

    final publishedAt = parseDate(el);
    if (publishedAt == null) return null;

    final imageUrls = parseImageUrls(el);
    final videoUrls = parseVideoUrls(el);
    final text = _parseCommentHtml(el);

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

  static String? _parseCommentHtml(Element el) {
    final textDiv = el.querySelector('.text');
    if (textDiv == null) return null;
    final clone = textDiv.clone(true);
    clone.querySelector('.tags')?.remove();
    for (final img in clone.querySelectorAll('img')) { img.remove(); }
    for (final video in clone.querySelectorAll('video')) { video.remove(); }
    final html = clone.innerHtml.trim();
    return html.isEmpty ? null : html;
  }

  static CommentsPaginationInfo _parseCommentsPagination(Document doc) {
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
}
