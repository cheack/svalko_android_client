import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/data/parsers/feed_parser.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/feed_page.html').readAsStringSync();
  });

  group('FeedParser', () {
    test('parses non-empty list of posts', () {
      final result = FeedParser.parse(html);
      expect(result.posts, isNotEmpty);
    });

    test('each post has valid id > 0', () {
      final result = FeedParser.parse(html);
      for (final post in result.posts) {
        expect(post.id, greaterThan(0), reason: 'bad id on post ${post.id}');
      }
    });

    test('each post has non-empty author name', () {
      final result = FeedParser.parse(html);
      for (final post in result.posts) {
        expect(post.author.name, isNotEmpty);
      }
    });

    test('each post has a publishedAt date', () {
      final result = FeedParser.parse(html);
      for (final post in result.posts) {
        expect(post.publishedAt.year, greaterThan(2000));
      }
    });

    test('pagination currentPage >= 1', () {
      final result = FeedParser.parse(html);
      expect(result.pagination.currentPage, greaterThanOrEqualTo(1));
    });

    test('pagination maxPage >= currentPage', () {
      final result = FeedParser.parse(html);
      expect(result.pagination.maxPage,
          greaterThanOrEqualTo(result.pagination.currentPage));
    });

    test('first post on fixture has known id 1018683', () {
      final result = FeedParser.parse(html);
      expect(result.posts.first.id, equals(1018683));
    });

    test('first post has tags', () {
      final result = FeedParser.parse(html);
      expect(result.posts.first.tags, isNotEmpty);
    });

    test('first post has rating', () {
      final result = FeedParser.parse(html);
      expect(result.posts.first.rating, isNotNull);
    });
  });

  group('FeedParser — kum posts', () {
    late FeedParseResult result;

    setUpAll(() {
      final kumHtml = File('test/fixtures/kum_feed_page.html').readAsStringSync();
      result = FeedParser.parse(kumHtml);
    });

    test('parses two posts', () {
      expect(result.posts.length, equals(2));
    });

    test('regular post has isKum = false', () {
      final post = result.posts.firstWhere((p) => p.id == 100001);
      expect(post.isKum, isFalse);
    });

    test('kum post has isKum = true', () {
      final post = result.posts.firstWhere((p) => p.id == 100002);
      expect(post.isKum, isTrue);
    });
  });
}
