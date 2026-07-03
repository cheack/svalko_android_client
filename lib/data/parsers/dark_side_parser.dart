import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/dark_side_post.dart';
import 'feed_parser.dart' show FeedPaginationInfo;
import 'post_element_helpers.dart' show tryParseDateTime;

final _imgTagRe = RegExp(r'''<img[^>]*src=["']([^"']+)["'][^>]*>''', caseSensitive: false);
final _urlRe = RegExp(r'https?://\S+');

abstract final class DarkSideParser {
  static ({List<DarkSidePost> posts, FeedPaginationInfo pagination}) parse(
    String htmlContent,
  ) {
    final doc = html_parser.parse(htmlContent);
    return (posts: _parsePosts(doc), pagination: _parsePagination(doc));
  }

  /// Parses the standalone post page (e.g. reached via /random.html), which
  /// has no `a[name]` anchor or post-list wrapper — just one content/author row.
  static DarkSidePost? parseSinglePost(String htmlContent, {required int id}) {
    final doc = html_parser.parse(htmlContent);
    final contentTd = doc.querySelector('td[align="left"][width="100%"]');
    final row = contentTd?.parent;
    if (contentTd == null || row == null) return null;
    return _parsePostRow(id: id, contentTd: contentTd, row: row);
  }

  static List<DarkSidePost> _parsePosts(Document doc) {
    final result = <DarkSidePost>[];
    for (final anchor in doc.querySelectorAll('a[name]')) {
      try {
        final name = anchor.attributes['name'] ?? '';
        if (!name.startsWith('a')) continue;
        final id = int.tryParse(name.substring(1));
        final contentTd = anchor.parent;
        final row = contentTd?.parent;
        if (id == null || contentTd == null || row == null) continue;
        final post = _parsePostRow(id: id, contentTd: contentTd, row: row);
        if (post != null) result.add(post);
      } catch (_) {
        // skip broken post, keep parsing the rest
      }
    }
    return result;
  }

  static DarkSidePost? _parsePostRow({
    required int id,
    required Element contentTd,
    required Element row,
  }) {
    final author = row.querySelector('.author b')?.text.trim() ?? '';
    final publishedAt =
        tryParseDateTime(row.querySelector('.author nobr')?.text.trim() ?? '');
    if (publishedAt == null) return null;

    final authorPostCountMatch =
        RegExp(r'Всего постов:\s*(\d+)').firstMatch(row.querySelector('.author')?.text ?? '');
    final authorPostCount = int.tryParse(authorPostCountMatch?.group(1) ?? '');

    final (approvedBy, approverComment) = _parseApproverNote(contentTd.querySelector('i'));
    final approverCommentParts =
        approverComment == null ? const <DarkSideTextPart>[] : _linkify(approverComment);

    final clone = contentTd.clone(true);
    clone.querySelectorAll('iframe, span.preview, i').forEach((e) => e.remove());

    final imageUrls = <String>[];
    final rawParts = <DarkSideTextPart>[];
    final buffer = StringBuffer();
    for (final node in clone.nodes) {
      _walk(node, rawParts, buffer);
    }
    _flush(rawParts, buffer);

    final textParts = _extractImages(rawParts, imageUrls);

    return DarkSidePost(
      id: id,
      author: author,
      publishedAt: publishedAt,
      textParts: textParts,
      imageUrls: imageUrls,
      approvedBy: approvedBy,
      approverComment: approverComment,
      approverCommentParts: approverCommentParts,
      authorPostCount: authorPostCount,
    );
  }

  /// Splits [text] into plain-text and link parts, auto-linkifying any
  /// `http(s)://` URL found (the site doesn't render these as real anchors).
  static List<DarkSideTextPart> _linkify(String text) {
    final parts = <DarkSideTextPart>[];
    var last = 0;
    for (final match in _urlRe.allMatches(text)) {
      if (match.start > last) parts.add(DarkSideText(text.substring(last, match.start)));
      final url = match.group(0)!;
      parts.add(DarkSideLink(url, url));
      last = match.end;
    }
    if (last < text.length) parts.add(DarkSideText(text.substring(last)));
    return parts;
  }

  /// The approver note looks like `<i>Name: comment</i>` — splits on the first colon.
  static (String?, String?) _parseApproverNote(Element? i) {
    final raw = i?.text.trim();
    if (raw == null || raw.isEmpty) return (null, null);
    final idx = raw.indexOf(':');
    if (idx < 0) return (null, raw);
    return (raw.substring(0, idx).trim(), raw.substring(idx + 1).trim());
  }

  static void _walk(Node node, List<DarkSideTextPart> parts, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.data);
      return;
    }
    if (node is! Element) return;
    switch (node.localName) {
      case 'br':
        buffer.write('\n');
      case 'a':
        final href = node.attributes['href'];
        final label = node.text.trim();
        if (href != null && href.isNotEmpty && label.isNotEmpty) {
          _flush(parts, buffer);
          parts.add(DarkSideLink(label, _resolveUrl(href)));
        } else {
          buffer.write(label);
        }
      case 'iframe':
        // dropped entirely — no visible content
        break;
      default:
        if (node.classes.contains('preview')) break;
        for (final child in node.nodes) {
          _walk(child, parts, buffer);
        }
    }
  }

  static void _flush(List<DarkSideTextPart> parts, StringBuffer buffer) {
    if (buffer.isNotEmpty) {
      parts.add(DarkSideText(buffer.toString()));
      buffer.clear();
    }
  }

  /// Pulls HTML-escaped `<img>` tags (rendered as literal text by the site)
  /// out of [parts] and into [imageUrls], stripping the matched text.
  static List<DarkSideTextPart> _extractImages(
    List<DarkSideTextPart> parts,
    List<String> imageUrls,
  ) {
    final result = <DarkSideTextPart>[];
    for (final part in parts) {
      if (part is! DarkSideText) {
        result.add(part);
        continue;
      }
      imageUrls.addAll(
        _imgTagRe.allMatches(part.text).map((m) => _resolveUrl(m.group(1)!)),
      );
      final cleaned = part.text.replaceAll(_imgTagRe, '').trim();
      if (cleaned.isNotEmpty) result.add(DarkSideText(cleaned));
    }
    return result;
  }

  static String _resolveUrl(String url) =>
      Uri.parse(Config.baseUrl).resolve(url).toString();

  static FeedPaginationInfo _parsePagination(Document doc) {
    final pagingRow = doc
        .querySelectorAll('tr')
        .where((tr) => tr.text.contains('Pages:'))
        .firstOrNull;
    final html = pagingRow?.innerHtml ?? '';
    final currentMatch = RegExp(r'<b>\[(\d+)\]</b>').firstMatch(html);
    final current = int.tryParse(currentMatch?.group(1) ?? '') ?? 0;
    final allNums = RegExp(r'\[(\d+)\]')
        .allMatches(html)
        .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
        .toList();
    final maxPage = allNums.isEmpty ? 0 : allNums.reduce((a, b) => a > b ? a : b);
    return FeedPaginationInfo(currentPage: current, maxPage: maxPage);
  }
}
