import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/config.dart';
import 'package:svalko_client/data/parsers/dark_side_parser.dart';

void main() {
  late String html;
  late String htmlWithImage;
  late String randomPostHtml;

  setUpAll(() {
    html = File('test/fixtures/dark_side_feed_page.html').readAsStringSync();
    htmlWithImage =
        File('test/fixtures/dark_side_feed_page_with_image.html').readAsStringSync();
    randomPostHtml = File('test/fixtures/dark_side_random_post.html').readAsStringSync();
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

  group('DarkSideParser.parseSinglePost', () {
    test('parses the standalone post page (e.g. from /random.html)', () {
      final post = DarkSideParser.parseSinglePost(randomPostHtml, id: 130343);
      expect(post, isNotNull);
      expect(post!.id, 130343);
      expect(post.author, 'Бибот');
      expect(post.publishedAt, DateTime(2020, 1, 28, 21, 40, 5));
      expect(post.externalLinks, isNotEmpty);
      expect(
        post.externalLinks.first,
        startsWith('https://upload.wikimedia.org/'),
      );
    });

    test('returns null for markup that does not match the expected shape', () {
      final post = DarkSideParser.parseSinglePost('<html><body>nope</body></html>', id: 1);
      expect(post, isNull);
    });
  });
}
