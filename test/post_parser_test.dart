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

  group('PostParser — YouTube-only comment', () {
    const youtubePostId = 1019849;
    late List<dynamic> comments;

    setUpAll(() {
      final html = File('test/fixtures/youtube_comment_page.html').readAsStringSync();
      final result = PostParser.parse(html, youtubePostId)!;
      comments = result.comments;
    });

    test('comment is parsed and not skipped', () {
      expect(comments.length, equals(1));
    });

    test('comment text is not null', () {
      expect(comments.first.text, isNotNull);
    });

    test('comment text contains YouTube thumbnail img', () {
      expect(comments.first.text, contains('<img'));
    });

    test('comment imageUrls is empty (thumbnail not in carousel)', () {
      expect(comments.first.imageUrls, isEmpty);
    });

    test('comment videoUrls is empty', () {
      expect(comments.first.videoUrls, isEmpty);
    });
  });

  group('PostParser — kum comments', () {
    const kumPostId = 700144;
    late List<dynamic> comments;

    setUpAll(() {
      final html = File('test/fixtures/kum_comment_page.html').readAsStringSync();
      final result = PostParser.parse(html, kumPostId)!;
      comments = result.comments;
    });

    test('parses two comments', () {
      expect(comments.length, equals(2));
    });

    test('regular comment has isKum = false', () {
      final regular = comments.firstWhere((c) => c.id == 700288);
      expect(regular.isKum, isFalse);
    });

    test('kum comment has isKum = true', () {
      final kum = comments.firstWhere((c) => c.id == 700295);
      expect(kum.isKum, isTrue);
    });
  });

  group('PostParser — kum pagination', () {
    const kumPostId = 100003;
    late PostParseResult result;

    setUpAll(() {
      final html = File('test/fixtures/kum_pagination_page.html').readAsStringSync();
      result = PostParser.parse(html, kumPostId)!;
    });

    test('pagination isKum = true', () {
      expect(result.pagination.isKum, isTrue);
    });

    test('pagination totalComments parsed correctly', () {
      expect(result.pagination.totalComments, equals(50));
    });

    test('pagination totalPages parsed correctly', () {
      expect(result.pagination.totalPages, equals(3));
    });

    test('non-kum pagination has isKum = false', () {
      final html = File('test/fixtures/post_page.html').readAsStringSync();
      final r = PostParser.parse(html, postId)!;
      expect(r.pagination.isKum, isFalse);
    });
  });
}
