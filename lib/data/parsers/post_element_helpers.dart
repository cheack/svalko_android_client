import 'package:html/dom.dart';
import '../../core/config.dart';
import '../../models/author.dart';
import '../../models/post.dart';
import '../../models/tag.dart';
import 'text_extractor.dart';

final _imageViewRe = RegExp(r"image_view\('[^']*',\s*'([^']+)'");
final _tagIdRe = RegExp(r'/tag/(\d+)');
final _ratingRe = RegExp(r'([+-]?\d+)\|(\d+)\|([+-]?\d+)\s*=\s*([+-]?\d+)%');
final _dateCleanRe = RegExp(r'\s+');

Author? parseAuthor(Element el) {
  final a = el.querySelector('.info .author a');
  if (a == null) return null;
  final href = a.attributes['href'] ?? '';
  return Author(
    name: a.text.trim(),
    profileUrl: href.startsWith('http') ? href : '${Config.baseUrl}/$href',
  );
}

DateTime? parseDate(Element el) {
  final infoEl = el.querySelector('.info');
  if (infoEl == null) return null;
  for (final node in infoEl.nodes) {
    if (node.nodeType == Node.TEXT_NODE) {
      final dt = tryParseDateTime(node.text?.trim() ?? '');
      if (dt != null) return dt;
    }
  }
  return null;
}

DateTime? tryParseDateTime(String s) {
  final clean = s.replaceAll(_dateCleanRe, ' ').trim();
  if (clean.length < 19) return null;
  try {
    return DateTime.parse(clean.substring(0, 19));
  } catch (_) {
    return null;
  }
}

PostRating? parseRating(Element el, int id) {
  final span = el.querySelector('#rating_span_$id');
  if (span == null) return null;
  final match = _ratingRe.firstMatch(span.text);
  if (match == null) return null;
  return PostRating(
    plus: int.parse(match.group(1)!),
    neutral: int.parse(match.group(2)!),
    minus: int.parse(match.group(3)!),
    percentage: int.parse(match.group(4)!),
  );
}

int? parseBorodaCount(Element el, int id) {
  final span = el.querySelector('#cur_boroda_span_$id');
  return int.tryParse(span?.text.trim() ?? '');
}

String? parseApprovedBy(Element el) =>
    el.querySelector('.info small a')?.text.trim();

List<String> parseImageUrls(Element el) {
  final textDiv = el.querySelector('.text');
  if (textDiv == null) return const [];
  return textDiv.querySelectorAll('img').map((img) {
    final parent = img.parent;
    final href = parent?.attributes['href'] ?? '';
    final imageViewMatch = _imageViewRe.firstMatch(href);
    if (imageViewMatch != null) return '${Config.baseUrl}/data/${imageViewMatch.group(1)}';
    if (parent?.classes.contains('gifplayer') == true && href.isNotEmpty) {
      return resolveUrl(href);
    }
    return resolveUrl(img.attributes['src'] ?? '');
  }).where((u) => u.isNotEmpty).toList();
}

List<String> parseVideoUrls(Element el) {
  final textDiv = el.querySelector('.text');
  if (textDiv == null) return const [];
  return textDiv
      .querySelectorAll('video source[src]')
      .map((s) => resolveUrl(s.attributes['src'] ?? ''))
      .where((u) => u.isNotEmpty)
      .toList();
}

List<String> parseExternalLinks(Element el) {
  final textDiv = el.querySelector('.text');
  if (textDiv == null) return const [];
  return textDiv
      .querySelectorAll('a[href]')
      .map((a) => a.attributes['href'] ?? '')
      .where((h) => h.startsWith('http'))
      .toList();
}

List<Tag> parseTags(Element el) {
  return el.querySelectorAll('.tags a[href]').expand((a) {
    final href = a.attributes['href'] ?? '';
    final idMatch = _tagIdRe.firstMatch(href);
    if (idMatch == null) return const <Tag>[];
    final id = int.tryParse(idMatch.group(1) ?? '') ?? 0;
    return [Tag(id: id, name: a.text.trim())];
  }).toList();
}

String? parseText(Element el) {
  final textDiv = el.querySelector('.text');
  if (textDiv == null) return null;
  final clone = textDiv.clone(true);
  clone.querySelector('.tags')?.remove();
  final raw = extractText(clone);
  return raw.isEmpty ? null : raw;
}

String resolveUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return '${Config.baseUrl}/$url';
}
