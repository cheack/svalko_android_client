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
      expect(items, hasLength(5));
    });

    test('item with title: parses id, title, author, date, image url', () {
      final item = items[0];
      expect(item.id, 1021136);
      expect(item.title, 'При лег отдохнуть или сбрусло?');
      expect(item.author, 'Бибоход');
      expect(item.publishedAt, DateTime.parse('2026-06-10T12:49:39Z'));
      expect(item.imageUrl.toString(), 'https://svalko.org/data/2026_06_10_15_49pic.webp');
    });

    test('self-closing empty title: raw title is empty, displayTitle returns fallback', () {
      final item = items[1];
      expect(item.title, '');
      expect(item.displayTitle, 'Новая запись');
    });

    test('text + image: imageUrl extracted even when image follows text', () {
      final item = items[2];
      expect(item.id, 1020048);
      expect(item.title, 'А это на среду');
      expect(item.imageUrl.toString(), 'https://svalko.org/data/2026_05_27_15_31pic.jpg');
    });

    test('text-only post: imageUrl is null', () {
      final item = items[3];
      expect(item.id, 1019849);
      expect(item.imageUrl, isNull);
    });

    test('extracts id from guid when guid is present', () {
      expect(items[0].id, 1021136);
    });

    test('extracts id from link when guid is absent', () {
      expect(items[4].id, 1020500);
    });
  });
}
