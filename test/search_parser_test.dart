import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/data/parsers/search_parser.dart';
import 'package:svalko_client/models/search_result.dart';

void main() {
  late SearchParseResult result;

  setUpAll(() {
    final html = File('test/fixtures/search_page.html').readAsStringSync();
    result = SearchParser.parse(html);
  });

  // ---------------------------------------------------------------------------
  // Top-level
  // ---------------------------------------------------------------------------

  group('SearchParser - top-level', () {
    test('parses total count', () {
      expect(result.totalCount, equals(42));
    });

    test('hasMore is true when "ещё" link is present', () {
      expect(result.hasMore, isTrue);
    });

    test('hasMore is false when "ещё" link is absent', () {
      const noMoreHtml = '''
        <html><body>
        <b>&nbsp;&nbsp;Results: <font color="red">1</font></b>
        <table id="result_feed">
          <tr class="search1">
            <td><b>Автор</b><br/><nobr><font size="-2">2026-01-01 00:00:00</font></nobr></td>
            <td>Текст <a href="/1.html">link</a></td>
          </tr>
        </table>
        </body></html>''';
      final r = SearchParser.parse(noMoreHtml);
      expect(r.hasMore, isFalse);
    });

    test('returns 3 results from fixture', () {
      expect(result.results.length, equals(3));
    });

    test('returns empty list on page with no results', () {
      const emptyHtml = '''
        <html><body>
        <b>&nbsp;&nbsp;Results: <font color="red">0</font></b>
        <table id="result_feed"></table>
        </body></html>''';
      final r = SearchParser.parse(emptyHtml);
      expect(r.results, isEmpty);
      expect(r.totalCount, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Comment result (first row)
  // ---------------------------------------------------------------------------

  group('SearchParser - comment result', () {
    late SearchResult comment;

    setUpAll(() => comment = result.results[0]);

    test('isComment is true', () {
      expect(comment.isComment, isTrue);
    });

    test('postId is correct', () {
      expect(comment.postId, equals(304732));
    });

    test('commentId is correct', () {
      expect(comment.commentId, equals(1020108));
    });

    test('author is parsed', () {
      expect(comment.author, equals('Тестовый автор'));
    });

    test('publishedAt year/month/day are correct', () {
      expect(comment.publishedAt.year, equals(2026));
      expect(comment.publishedAt.month, equals(5));
      expect(comment.publishedAt.day, equals(27));
    });

    test('textHtml is non-empty', () {
      expect(comment.textHtml, isNotEmpty);
    });

    test('textHtml does not contain the svalko "link" anchor', () {
      expect(comment.textHtml, isNot(contains('/304732.html#c1020108')));
    });
  });

  // ---------------------------------------------------------------------------
  // Post result (second row)
  // ---------------------------------------------------------------------------

  group('SearchParser - post result', () {
    late SearchResult post;

    setUpAll(() => post = result.results[1]);

    test('isComment is false', () {
      expect(post.isComment, isFalse);
    });

    test('commentId is null', () {
      expect(post.commentId, isNull);
    });

    test('postId is correct', () {
      expect(post.postId, equals(969915));
    });

    test('author is parsed', () {
      expect(post.author, equals('Другой автор'));
    });

    test('publishedAt is correct', () {
      expect(post.publishedAt, equals(DateTime(2026, 4, 15, 10, 30, 0)));
    });

    test('textHtml contains line break', () {
      expect(post.textHtml, contains('<br'));
    });
  });

  // ---------------------------------------------------------------------------
  // External link in content (third row — regression for the parser bug)
  // ---------------------------------------------------------------------------

  group('SearchParser - external link in content', () {
    late SearchResult extLink;

    setUpAll(() => extLink = result.results[2]);

    test('postId is parsed from the svalko "link" anchor, not the external one',
        () {
      expect(extLink.postId, equals(53388));
    });

    test('isComment is false (plain post link)', () {
      expect(extLink.isComment, isFalse);
    });

    test('textHtml still contains the external URL', () {
      expect(extLink.textHtml,
          contains('sysval.livejournal.com'));
    });

    test('textHtml does not contain the svalko "link" anchor', () {
      expect(extLink.textHtml, isNot(contains('/53388.html')));
    });
  });

  // ---------------------------------------------------------------------------
  // All results invariants
  // ---------------------------------------------------------------------------

  group('SearchParser - all results', () {
    test('every result has a non-empty author', () {
      for (final r in result.results) {
        expect(r.author, isNotEmpty,
            reason: 'empty author for post ${r.postId}');
      }
    });

    test('every result has postId > 0', () {
      for (final r in result.results) {
        expect(r.postId, greaterThan(0));
      }
    });

    test('every result has publishedAt year > 2000', () {
      for (final r in result.results) {
        expect(r.publishedAt.year, greaterThan(2000));
      }
    });

    test('comment results have commentId > 0', () {
      for (final r in result.results.where((r) => r.isComment)) {
        expect(r.commentId, greaterThan(0));
      }
    });

    test('post results have commentId == null', () {
      for (final r in result.results.where((r) => !r.isComment)) {
        expect(r.commentId, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // SearchParams equality
  // ---------------------------------------------------------------------------

  group('SearchParams equality', () {
    test('equal when all fields match', () {
      const a = SearchParams(query: 'test', order: 'rel', searchComments: true);
      const b = SearchParams(query: 'test', order: 'rel', searchComments: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when query differs', () {
      const a = SearchParams(query: 'foo');
      const b = SearchParams(query: 'bar');
      expect(a, isNot(equals(b)));
    });

    test('not equal when order differs', () {
      const a = SearchParams(query: 'x', order: 'rel');
      const b = SearchParams(query: 'x', order: 'date');
      expect(a, isNot(equals(b)));
    });

    test('not equal when searchComments differs', () {
      const a = SearchParams(query: 'x', searchComments: true);
      const b = SearchParams(query: 'x', searchComments: false);
      expect(a, isNot(equals(b)));
    });

    test('defaults: order=rel, searchComments=true', () {
      const p = SearchParams(query: 'x');
      expect(p.order, equals('rel'));
      expect(p.searchComments, isTrue);
    });
  });
}
