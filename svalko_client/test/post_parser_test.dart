import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/data/parsers/post_parser.dart';

void main() {
  const postId = 49131;
  late String html;

  setUpAll(() {
    html = File('test/fixtures/post_page.html').readAsStringSync();
  });

  group('PostParser', () {
    test('returns non-null result', () {
      expect(PostParser.parse(html, postId), isNotNull);
    });

    test('post id matches requested id', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.post.id, equals(postId));
    });

    test('post author is non-empty', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.post.author.name, isNotEmpty);
    });

    test('post publishedAt year is valid', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.post.publishedAt.year, greaterThan(2000));
    });

    test('post has tags', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.post.tags, isNotEmpty);
    });

    test('post has rating', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.post.rating, isNotNull);
      expect(result.post.rating!.plus, greaterThanOrEqualTo(0));
    });

    test('comments list is non-empty', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.comments, isNotEmpty);
    });

    test('each comment has valid id > 0', () {
      final result = PostParser.parse(html, postId)!;
      for (final c in result.comments) {
        expect(c.id, greaterThan(0));
        expect(c.postId, equals(postId));
      }
    });

    test('each comment has non-empty author', () {
      final result = PostParser.parse(html, postId)!;
      for (final c in result.comments) {
        expect(c.author.name, isNotEmpty);
      }
    });

    test('each comment has a valid date', () {
      final result = PostParser.parse(html, postId)!;
      for (final c in result.comments) {
        expect(c.publishedAt.year, greaterThan(2000));
      }
    });

    test('pagination totalComments > 0', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.pagination.totalComments, greaterThan(0));
    });

    test('pagination totalPages > 0', () {
      final result = PostParser.parse(html, postId)!;
      expect(result.pagination.totalPages, greaterThan(0));
    });
  });
}
