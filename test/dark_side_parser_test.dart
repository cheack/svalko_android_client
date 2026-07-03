import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/config.dart';
import 'package:svalko_client/data/parsers/dark_side_parser.dart';

void main() {
  late String html;
  late String htmlWithImage;

  setUpAll(() {
    html = File('test/fixtures/dark_side_feed_page.html').readAsStringSync();
    htmlWithImage =
        File('test/fixtures/dark_side_feed_page_with_image.html').readAsStringSync();
    Config.setBaseUrl('https://dark.side.of.svalko.org');
  });

  group('DarkSideParser', () {
    test('parses non-empty list of posts', () {
      final result = DarkSideParser.parse(html);
      expect(result.posts, isNotEmpty);
    });

    test('each post has valid id > 0', () {
      final result = DarkSideParser.parse(html);
      for (final post in result.posts) {
        expect(post.id, greaterThan(0));
      }
    });

    test('each post has a publishedAt date', () {
      final result = DarkSideParser.parse(html);
      for (final post in result.posts) {
        expect(post.publishedAt.year, greaterThan(2000));
      }
    });

    test('extracts image urls embedded as escaped <img> tags, absolute and resolved', () {
      final result = DarkSideParser.parse(htmlWithImage);
      final withImages = result.posts.where((p) => p.imageUrls.isNotEmpty);
      expect(withImages, isNotEmpty);
      for (final post in withImages) {
        for (final url in post.imageUrls) {
          expect(url, startsWith('https://dark.side.of.svalko.org/'));
        }
      }
    });

    test('post text does not contain leftover <img> tag markup', () {
      final result = DarkSideParser.parse(htmlWithImage);
      for (final post in result.posts) {
        expect(post.text ?? '', isNot(contains('<img')));
      }
    });

    test('pagination maxPage is at least currentPage', () {
      final result = DarkSideParser.parse(html);
      expect(result.pagination.maxPage, greaterThanOrEqualTo(result.pagination.currentPage));
    });
  });
}
