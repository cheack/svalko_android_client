import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/tag.dart';

abstract final class TagsParser {
  static List<Tag> parse(String html) {
    final doc = html_parser.parse(html);
    final anchors = doc.querySelectorAll('a[href]');
    final tagHrefRe = RegExp(r'^/tag/(\d+)$');
    final countRe = RegExp(r'"(\d+)"');
    final result = <Tag>[];

    for (final a in anchors) {
      final href = a.attributes['href'] ?? '';
      final hrefMatch = tagHrefRe.firstMatch(href);
      if (hrefMatch == null) continue;
      final id = int.tryParse(hrefMatch.group(1)!);
      if (id == null) continue;
      final name = a.text.trim();
      if (name.isEmpty) continue;

      int? count;
      final parent = a.parent;
      if (parent != null) {
        final idx = parent.nodes.indexOf(a);
        if (idx >= 0 && idx + 1 < parent.nodes.length) {
          final next = parent.nodes[idx + 1];
          if (next.nodeType == Node.TEXT_NODE) {
            final countMatch = countRe.firstMatch(next.text ?? '');
            if (countMatch != null) count = int.tryParse(countMatch.group(1)!);
          }
        }
      }

      result.add(Tag(id: id, name: name, count: count));
    }

    result.sort((a, b) => (b.count ?? 0).compareTo(a.count ?? 0));
    return result;
  }
}
