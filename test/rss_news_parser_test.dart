import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/features/news/rss_news_parser.dart';

void main() {
  late List<dynamic> items;

  setUpAll(() {
    final xml = File('test/fixtures/news_feed.rss').readAsStringSync();
    items = RssNewsParser.parse(xml);
  });

  group('RssNewsParser', () {
    test('parses all items from fixture', () {
      expect(items, hasLength(3));
    });

    test('item with title: parses id, title, author, date, image url', () {
      final item = items[0];
      expect(item.id, 1021136);
      expect(item.title, 'При лег отдохнуть или сбрусло?');
      expect(item.author, 'Бибоход');
      expect(item.publishedAt, DateTime.parse('2026-06-10T12:49:39Z'));
      expect(item.imageUrl.toString(), 'https://svalko.org/data/pic.webp');
    });

    test('item without title: raw title is empty, displayTitle returns fallback', () {
      final item = items[1];
      expect(item.title, '');
      expect(item.displayTitle, 'Новая запись');
    });

    test('extracts id from guid when guid is present', () {
      expect(items[0].id, 1021136);
    });

    test('extracts id from link when guid is absent', () {
      expect(items[2].id, 1020500);
    });
  });
}
