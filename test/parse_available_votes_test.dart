import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:svalko_client/data/parsers/post_element_helpers.dart';

Element _div(String inner) => html_parser.parse('<div>$inner</div>').body!.firstChild as Element;

const int _id = 1001933;

String _voteSpan(String links) =>
    '<span id="vote_form_$_id" class="vote">$links</span>';

void main() {
  group('parseAvailableVotes', () {
    test('returns [1] when only ЗАЧОТ is present (current site format)', () {
      final el = _div(_voteSpan('<a href="javascript:vote($_id, 1);">ЗАЧОТ</a>'));
      expect(parseAvailableVotes(el, _id), equals([1]));
    });

    test('returns all three values when all buttons are present (old format)', () {
      final el = _div(_voteSpan(
        '<a href="javascript:vote($_id, 0);">? я чото п</a>'
        '<a href="javascript:vote($_id, 1);">ЗАЧОТ</a>'
        '<a href="javascript:vote($_id, -1);">КГ/АМ</a>',
      ));
      expect(parseAvailableVotes(el, _id), equals([0, 1, -1]));
    });

    test('returns empty list when vote span is empty (already voted)', () {
      final el = _div(_voteSpan(''));
      expect(parseAvailableVotes(el, _id), isEmpty);
    });

    test('returns empty list when vote span is absent', () {
      final el = _div('<span id="other_$_id"></span>');
      expect(parseAvailableVotes(el, _id), isEmpty);
    });

    test('ignores links with unrecognised href format', () {
      final el = _div(_voteSpan(
        '<a href="javascript:vote($_id, 1);">ЗАЧОТ</a>'
        '<a href="/something-else">noise</a>',
      ));
      expect(parseAvailableVotes(el, _id), equals([1]));
    });

    test('does not bleed into a different post id', () {
      const otherId = 9999999;
      final el = _div(_voteSpan('<a href="javascript:vote($_id, 1);">ЗАЧОТ</a>'));
      expect(parseAvailableVotes(el, otherId), isEmpty);
    });
  });
}
