import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/dark_side_post.dart';
import 'feed_parser.dart' show FeedPaginationInfo;
import 'post_element_helpers.dart' show tryParseDateTime;

final _imgTagRe = RegExp(r'''<img[^>]*src=["']([^"']+)["'][^>]*>''', caseSensitive: false);

abstract final class DarkSideParser {
  static ({List<DarkSidePost> posts, FeedPaginationInfo pagination}) parse(
    String htmlContent,
  ) {
    final doc = html_parser.parse(htmlContent);
    return (posts: _parsePosts(doc), pagination: _parsePagination(doc));
  }

  static List<DarkSidePost> _parsePosts(Document doc) {
    final result = <DarkSidePost>[];
    for (final anchor in doc.querySelectorAll('a[name]')) {
      try {
        final post = _parsePostAnchor(anchor);
        if (post != null) result.add(post);
      } catch (_) {
        // skip broken post, keep parsing the rest
      }
    }
    return result;
  }

  static DarkSidePost? _parsePostAnchor(Element anchor) {
    final name = anchor.attributes['name'] ?? '';
    if (!name.startsWith('a')) return null;
    final id = int.tryParse(name.substring(1));
    if (id == null) return null;

    final contentTd = anchor.parent;
    final row = contentTd?.parent;
    if (contentTd == null || row == null) return null;

    final author = row.querySelector('.author b')?.text.trim() ?? '';
    final publishedAt =
        tryParseDateTime(row.querySelector('.author nobr')?.text.trim() ?? '');
    if (publishedAt == null) return null;

    final externalLinks = contentTd
        .querySelectorAll('a[href]')
        .map((a) => a.attributes['href'] ?? '')
        .where((h) => h.isNotEmpty)
        .toList();

    final clone = contentTd.clone(true);
    clone.querySelectorAll('iframe, span.preview, i').forEach((e) => e.remove());
    final rawText = clone.text.trim();

    final imageUrls = _imgTagRe
        .allMatches(rawText)
        .map((m) => _resolveUrl(m.group(1)!))
        .toList();
    final text = rawText.replaceAll(_imgTagRe, '').trim();

    return DarkSidePost(
      id: id,
      author: author,
      publishedAt: publishedAt,
      text: text.isEmpty ? null : text,
      imageUrls: imageUrls,
      externalLinks: externalLinks,
    );
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
