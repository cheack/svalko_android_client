import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../core/config.dart';
import 'news_item.dart';

abstract final class RssNewsParser {
  static List<NewsItem> parse(String xmlContent) {
    final doc = XmlDocument.parse(xmlContent);
    return doc
        .findAllElements('item')
        .map(_parseItem)
        .whereType<NewsItem>()
        .toList();
  }

  static NewsItem? _parseItem(XmlElement item) {
    final linkText = _childText(item, 'guid').ifEmpty(_childText(item, 'link'));
    final id = _extractPostId(linkText);
    if (id == null) return null;

    final link =
        Uri.tryParse(_childText(item, 'link')) ??
        Uri.parse('${Config.baseUrl}/$id.html');
    final description = _childText(item, 'description');

    return NewsItem(
      id: id,
      title: _normalizeText(_childText(item, 'title')),
      author: _parseAuthor(_childText(item, 'author')),
      publishedAt: _parseDate(_childText(item, 'pubDate')),
      link: link,
      descriptionHtml: description,
      imageUrl: _extractImageUrl(description),
    );
  }

  static String _childText(XmlElement item, String name) =>
      item.getElement(name)?.innerText.trim() ?? '';

  static int? _extractPostId(String value) {
    final match = RegExp(r'/(\d+)\.html').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '');
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final rss = _parseRssDate(value);
    if (rss != null) return rss;
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseRssDate(String value) {
    final match = RegExp(
      r'^\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$',
    ).firstMatch(value);
    if (match == null) return null;

    final month = const {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    }[match.group(2)];
    if (month == null) return null;

    final local = DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    final offset = Duration(
      hours: int.parse(match.group(8)!),
      minutes: int.parse(match.group(9)!),
    );
    return match.group(7) == '+' ? local.subtract(offset) : local.add(offset);
  }

  static String _parseAuthor(String value) {
    final match = RegExp(r'\((.+)\)').firstMatch(value);
    return _normalizeText(match?.group(1) ?? value);
  }

  static Uri? _extractImageUrl(String descriptionHtml) {
    if (descriptionHtml.trim().isEmpty) return null;
    final fragment = html_parser.parseFragment(descriptionHtml);
    final src = fragment.querySelector('img')?.attributes['src']?.trim();
    if (src == null || src.isEmpty || src.startsWith('data:')) return null;
    return Uri.parse(Config.baseUrl).resolve(src);
  }

  static String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
