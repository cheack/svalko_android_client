import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/last_item.dart';

abstract final class LastParser {
  static (List<LastComment>, List<LastImage>) parse(String html) {
    final doc = html_parser.parse(html);

    // Outer wrapper: <table><tr><td valign="top">comments</td><td valign="top">images</td>
    final cols = doc.querySelectorAll('td[valign="top"]');
    if (cols.length < 2) return ([], []);

    final commentRows = cols[0].querySelectorAll('tr.c_cols td');
    final imageRows = cols[1].querySelectorAll('tr.c_cols td');

    return (_parseComments(commentRows), _parseImages(imageRows));
  }

  static final _linkRe = RegExp(r'/(\d+)\.html\?high=(\d+)');
  static final _countRe = RegExp(r'(\d+):\s*(\d+)\s*комментари');

  static List<LastComment> _parseComments(List<Element> tds) {
    final result = <LastComment>[];
    for (final td in tds) {
      final small = td.querySelector('small');
      if (small == null) continue;

      final countMatch = _countRe.firstMatch(small.text);
      final commentCount = int.tryParse(countMatch?.group(2) ?? '') ?? 0;
      final ageText = small.querySelector('b')?.text ?? '';
      final topicAge = ageText.contains('очень')
          ? TopicAge.veryOld
          : ageText.isNotEmpty
              ? TopicAge.old
              : TopicAge.normal;

      final italic = td.querySelector('i');
      final postTitle = (italic?.text ?? '')
          .replaceAll('->', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Author <b> is a direct child of <td>; <small> may contain its own <b>
      final authorEl =
          td.children.where((el) => el.localName == 'b').firstOrNull;
      final author = authorEl?.text.trim() ?? '';

      final lastLink = td.querySelector('a.last');
      final href = lastLink?.attributes['href'] ?? '';
      final linkMatch = _linkRe.firstMatch(href);
      final postId = int.tryParse(linkMatch?.group(1) ?? '');
      final commentId = int.tryParse(linkMatch?.group(2) ?? '');
      if (postId == null || commentId == null) continue;

      // Comment HTML: everything between the author <b> and the "ссылка"
      // link, kept as markup (not flattened to text) so formatting like
      // <u>/<a>/[s] survives into the comment preview.
      final commentHtml = _extractCommentHtml(td, authorEl, lastLink);

      result.add(LastComment(
        author: author,
        postId: postId,
        commentId: commentId,
        postTitle: postTitle,
        commentHtml: commentHtml,
        commentCount: commentCount,
        topicAge: topicAge,
      ));
    }
    return result;
  }

  /// Everything between [authorEl] (exclusive) and [lastLink] (exclusive)
  /// inside [td], as HTML markup. Strips the leading ": " that follows the
  /// author name.
  static String _extractCommentHtml(
      Element td, Element? authorEl, Element? lastLink) {
    if (authorEl == null || lastLink == null) return '';
    final nodes = td.nodes;
    final start = nodes.indexOf(authorEl) + 1;
    final end = nodes.indexOf(lastLink);
    if (start <= 0 || end < 0 || start >= end) return '';

    final wrapper = Element.tag('div');
    for (var i = start; i < end; i++) {
      final node = nodes[i];
      if (i == start && node is Text) {
        final colonIdx = node.data.indexOf(':');
        final rest =
            colonIdx >= 0 ? node.data.substring(colonIdx + 1) : node.data;
        wrapper.append(Text(rest.trimLeft()));
      } else {
        wrapper.append(node.clone(true));
      }
    }
    return wrapper.innerHtml.trim();
  }

  static List<LastImage> _parseImages(List<Element> tds) {
    final result = <LastImage>[];
    for (final td in tds) {
      final img = td.querySelector('img');
      if (img == null) continue;

      final author = td.querySelector('b')?.text.trim() ?? '';
      final src = img.attributes['src'] ?? '';
      final thumbUrl =
          src.startsWith('http') ? src : '${Config.baseUrl}/$src';

      final lastLink = td.querySelector('a.last');
      final href = lastLink?.attributes['href'] ?? '';
      final linkMatch = _linkRe.firstMatch(href);
      final postId = int.tryParse(linkMatch?.group(1) ?? '');
      final commentId = int.tryParse(linkMatch?.group(2) ?? '');
      if (postId == null || commentId == null) continue;

      result.add(LastImage(
        author: author,
        postId: postId,
        commentId: commentId,
        thumbUrl: thumbUrl,
      ));
    }
    return result;
  }
}
