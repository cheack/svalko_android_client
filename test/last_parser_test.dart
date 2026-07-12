import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/data/parsers/last_parser.dart';
import 'package:svalko_client/models/last_item.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/last_page.html').readAsStringSync();
  });

  group('LastParser - comments', () {
    late List<LastComment> comments;

    setUpAll(() {
      comments = LastParser.parse(html).$1;
    });

    test('returns non-empty comment list', () {
      expect(comments, isNotEmpty);
    });

    test('each comment has valid postId > 0', () {
      for (final c in comments) {
        expect(c.postId, greaterThan(0), reason: 'bad postId in $c');
      }
    });

    test('each comment has valid commentId > 0', () {
      for (final c in comments) {
        expect(c.commentId, greaterThan(0), reason: 'bad commentId in $c');
      }
    });

    test('each comment has non-empty author', () {
      for (final c in comments) {
        expect(c.author, isNotEmpty, reason: 'empty author for post ${c.postId}');
      }
    });

    test('author is never "очень старую" or "старую"', () {
      for (final c in comments) {
        expect(c.author, isNot(contains('старую')),
            reason: 'author looks like topic age text: ${c.author}');
      }
    });

    test('commentCount >= 0', () {
      for (final c in comments) {
        expect(c.commentCount, greaterThanOrEqualTo(0));
      }
    });

    test('topicAge is a valid enum value', () {
      for (final c in comments) {
        expect(TopicAge.values, contains(c.topicAge));
      }
    });

    test('at least one comment has a non-empty postTitle', () {
      expect(comments.any((c) => c.postTitle.isNotEmpty), isTrue);
    });

    test('commentHtml preserves inline markup instead of flattening to text',
        () {
      final c = comments.firstWhere((c) => c.author == 'Рвун Чехлов');
      expect(c.commentHtml, contains('<a'));
    });

    test('commentHtml does not include the author prefix or trailing link',
        () {
      for (final c in comments) {
        expect(c.commentHtml, isNot(startsWith(':')),
            reason: 'leading ": " not stripped for post ${c.postId}');
        expect(c.commentHtml, isNot(contains('class="last"')),
            reason: 'trailing "ссылка" link leaked for post ${c.postId}');
      }
    });

    test('postTitle contains no raw newlines', () {
      for (final c in comments) {
        expect(c.postTitle, isNot(contains('\n')),
            reason: 'title not normalized for post ${c.postId}');
        expect(c.postTitle, isNot(contains('\r')),
            reason: 'title not normalized for post ${c.postId}');
      }
    });
  });

  group('LastParser - images', () {
    late List<LastImage> images;

    setUpAll(() {
      images = LastParser.parse(html).$2;
    });

    test('returns non-empty image list', () {
      expect(images, isNotEmpty);
    });

    test('each image has valid postId > 0', () {
      for (final img in images) {
        expect(img.postId, greaterThan(0));
      }
    });

    test('each image has valid commentId > 0', () {
      for (final img in images) {
        expect(img.commentId, greaterThan(0));
      }
    });

    test('each image has non-empty thumbUrl starting with http', () {
      for (final img in images) {
        expect(img.thumbUrl, startsWith('http'),
            reason: 'bad thumbUrl for post ${img.postId}');
      }
    });

    test('each image has non-empty author', () {
      for (final img in images) {
        expect(img.author, isNotEmpty);
      }
    });
  });

  group('LastParser - robustness', () {
    test('returns empty lists for empty html', () {
      final (comments, images) = LastParser.parse('');
      expect(comments, isEmpty);
      expect(images, isEmpty);
    });

    test('returns empty lists for html without expected structure', () {
      final (comments, images) = LastParser.parse('<html><body></body></html>');
      expect(comments, isEmpty);
      expect(images, isEmpty);
    });

    test('skips comment rows missing the link href', () {
      const badHtml = '''
        <table><tr>
          <td valign="top">
            <table><tr class="c_cols"><td>
              <small>1: 5 комментариев на  тему: </small><br/>
              <i>Тема без ссылки</i><br/><br/>
              <b>Автор</b>: текст
            </td></tr></table>
          </td>
          <td valign="top"></td>
        </tr></table>
      ''';
      final (comments, images) = LastParser.parse(badHtml);
      expect(comments, isEmpty);
    });

    test('skips image rows missing img tag', () {
      const badHtml = '''
        <table><tr>
          <td valign="top"></td>
          <td valign="top">
            <table><tr class="c_cols"><td>
              <b>Автор</b>
              <a class="last" href="/123.html?high=456#c456">ссылка</a>
            </td></tr></table>
          </td>
        </tr></table>
      ''';
      final (comments, images) = LastParser.parse(badHtml);
      expect(images, isEmpty);
    });

    test('does not throw on deeply malformed html', () {
      expect(
        () => LastParser.parse('<<<<<>><garbage>не html совсем'),
        returnsNormally,
      );
    });

    test('valid rows still parsed when mixed with invalid rows', () {
      // One valid comment row followed by one broken row (no link).
      final validRow = '''
        <tr class="c_cols"><td>
          <small>1: 3 комментариев на  тему: </small><br/>
          <i>Нормальная тема <a class="nav" href="/999.html">-&gt;</a></i><br/><br/>
          <b>Автор Нормальный</b>: текст
          <a class="last" href="/999.html?high=111#c111">ссылка</a>
        </td></tr>
      ''';
      final brokenRow = '''
        <tr class="c_cols"><td>
          <small>2: 1 комментариев на  тему: </small><br/>
          <b>Автор Сломанный</b>: текст без ссылки
        </td></tr>
      ''';
      final html = '''
        <table><tr>
          <td valign="top"><table>$validRow$brokenRow</table></td>
          <td valign="top"></td>
        </tr></table>
      ''';
      final (comments, _) = LastParser.parse(html);
      expect(comments.length, equals(1));
      expect(comments.first.postId, equals(999));
    });
  });
}
