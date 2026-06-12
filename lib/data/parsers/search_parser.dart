import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/search_result.dart';

class SearchParseResult {
  const SearchParseResult({
    required this.results,
    required this.totalCount,
    required this.hasMore,
  });

  final List<SearchResult> results;
  final int totalCount;
  final bool hasMore;
}

abstract final class SearchParser {
  static const pageSize = 15;

  static SearchParseResult parse(String html) {
    final doc = html_parser.parse(html);

    final countEl = doc.querySelector('b font[color="red"]');
    final totalCount = int.tryParse(countEl?.text.trim() ?? '') ?? 0;

    final rows = doc.querySelectorAll('tr.search1, tr.search2');
    final results = <SearchResult>[];
    for (final row in rows) {
      try {
        final r = _parseRow(row);
        if (r != null) results.add(r);
      } catch (_) {}
    }

    final hasMore = doc.querySelector('a#skip_link') != null;

    return SearchParseResult(
      results: results,
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  static SearchResult? _parseRow(Element row) {
    final tds = row.querySelectorAll('td');
    if (tds.length < 2) return null;

    final metaTd = tds[0];
    final contentTd = tds[1];

    final author = metaTd.querySelector('b')?.text.trim() ?? '';
    if (author.isEmpty) return null;

    final fonts = metaTd.querySelectorAll('font');
    final dateStr = fonts.isNotEmpty ? fonts[0].text.trim() : '';
    final publishedAt = DateTime.tryParse(dateStr) ?? DateTime(2000);

    final svalkoLinkRe = RegExp(r'^/\d+\.html(#c\d+)?$');
    final linkEl = contentTd
        .querySelectorAll('a[href]')
        .where((a) => svalkoLinkRe.hasMatch(a.attributes['href'] ?? ''))
        .lastOrNull;
    final href = linkEl?.attributes['href'] ?? '';
    linkEl?.remove();

    final textHtml = contentTd.innerHtml.trim();

    final commentMatch = RegExp(r'/(\d+)\.html#c(\d+)').firstMatch(href);
    if (commentMatch != null) {
      return SearchResult(
        author: author,
        publishedAt: publishedAt,
        textHtml: textHtml,
        postId: int.parse(commentMatch.group(1)!),
        commentId: int.parse(commentMatch.group(2)!),
      );
    }

    final postMatch = RegExp(r'/(\d+)\.html').firstMatch(href);
    if (postMatch != null) {
      return SearchResult(
        author: author,
        publishedAt: publishedAt,
        textHtml: textHtml,
        postId: int.parse(postMatch.group(1)!),
      );
    }

    return null;
  }
}
