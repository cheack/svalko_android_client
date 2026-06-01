import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:svalko_client/data/parsers/calendar_parser.dart';

Document _doc(String inner) => html_parser.parse('<html><body>$inner</body></html>');

String _calendar(String caption, String tbody) => '''
<div id="calendar"><table>
  <caption>$caption</caption>
  <thead><tr>
    <th>пн</th><th>вт</th><th>ср</th><th>пт</th><th>пт</th>
    <th class="red">сб</th><th class="red">вс</th>
  </tr></thead>
  <tbody>$tbody</tbody>
</table></div>
''';

String _td(String cls, String content) => '<td class="$cls">$content</td>';
String _a(String href, int day) => '<a href="$href">$day</a>';
String _span(int day) => '<span>$day</span>';

// Caption from the site for April 2026 (correct)
const _captionApr2026 = '''
  <a href="/2026/3/1/" class="nav2" style="float: left">← Prev</a>
  <a href="/2026/5/1/" class="nav2">Next →</a>
''';

// Buggy caption from the site for January 2026
const _captionJan2026Buggy = '''
  <a href="/2026/0/1/" class="nav2" style="float: left">← Prev</a>
  <a href="/2025/12/1/" class="nav2">Next →</a>
''';

void main() {
  group('CalendarParser.monthPath', () {
    test('normal month', () {
      expect(CalendarParser.monthPath(2026, 4), '/2026/4/1/');
    });

    test('month 0 wraps to December of previous year', () {
      expect(CalendarParser.monthPath(2026, 0), '/2025/12/1/');
    });

    test('month 13 wraps to January of next year', () {
      expect(CalendarParser.monthPath(2025, 13), '/2026/1/1/');
    });
  });

  group('CalendarParser.parse', () {
    test('returns null when no #calendar div', () {
      expect(CalendarParser.parse(_doc('<p>nothing here</p>')), isNull);
    });

    test('extracts year and month from active in-month day link', () {
      final tbody = '<tr>'
          '${_td('cd', _span(31))}'
          '${_td('c0', _a('/2026/04/1/', 1))}'
          '${_td('c2', _span(2))}'
          '</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionApr2026, tbody)));
      expect(cal?.year, 2026);
      expect(cal?.month, 4);
    });

    test('ignores buggy site nav links, computes prevPath/nextPath itself', () {
      final tbody = '<tr>'
          '${_td('cd', _span(29))}'
          '${_td('cc', _a('/2026/01/1/', 1))}'
          '${_td('c0', _span(2))}'
          '</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionJan2026Buggy, tbody)));
      expect(cal?.year, 2026);
      expect(cal?.month, 1);
      expect(cal?.prevPath, '/2025/12/1/');
      expect(cal?.nextPath, '/2026/2/1/'); // Feb 2026 is in the past → not null
    });

    test('prevPath is previous month', () {
      final tbody = '<tr>${_td('c0', _a('/2026/04/13/', 13))}</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionApr2026, tbody)));
      expect(cal?.prevPath, '/2026/3/1/');
    });

    test('nextPath is null for current month', () {
      final now = DateTime.now();
      final href = '/${now.year}/${now.month}/1/';
      final tbody = '<tr>${_td('c0', _a(href, 1))}</tr>';
      final cal = CalendarParser.parse(_doc(_calendar('', tbody)));
      expect(cal?.nextPath, isNull);
    });

    test('nextPath is set for past month', () {
      final tbody = '<tr>${_td('c0', _a('/2025/10/13/', 13))}</tr>';
      final cal = CalendarParser.parse(_doc(_calendar('', tbody)));
      expect(cal?.nextPath, '/2025/11/1/');
    });

    test('days: active in-month day has path', () {
      final tbody = '<tr>'
          '${_td('c0', _a('/2026/04/13/', 13))}'
          '${_td('c2', _span(14))}'
          '</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionApr2026, tbody)));
      final day13 = cal?.days.firstWhere((d) => d.day == 13);
      final day14 = cal?.days.firstWhere((d) => d.day == 14);
      expect(day13?.path, '/2026/04/13/');
      expect(day13?.isCurrentMonth, isTrue);
      expect(day14?.path, isNull);
      expect(day14?.isCurrentMonth, isTrue);
    });

    test('days: overflow day (cd) marked as not current month', () {
      final tbody = '<tr>'
          '${_td('cd', _a('/2026/03/31/', 31))}'
          '${_td('c0', _a('/2026/04/1/', 1))}'
          '</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionApr2026, tbody)));
      final day31 = cal?.days.firstWhere((d) => d.day == 31);
      expect(day31?.isCurrentMonth, isFalse);
      expect(day31?.path, '/2026/03/31/');
    });

    test('isToday is always false (cc class ignored)', () {
      final tbody = '<tr>${_td('cc', _a('/2026/04/16/', 16))}</tr>';
      final cal = CalendarParser.parse(_doc(_calendar(_captionApr2026, tbody)));
      expect(cal?.days.first.isToday, isFalse);
    });

    test('returns null when no in-month day links and no nav links', () {
      final tbody = '<tr>'
          '${_td('cd', _span(30))}'
          '${_td('c0', _span(1))}'
          '${_td('c0', _span(2))}'
          '</tr>';
      final cal = CalendarParser.parse(_doc(_calendar('', tbody)));
      expect(cal, isNull);
    });
  });

  group('CalendarParser.emptyMonth', () {
    test('has no days', () {
      final m = CalendarParser.emptyMonth(2025, 10);
      expect(m.days, isEmpty);
    });

    test('year and month are set correctly', () {
      final m = CalendarParser.emptyMonth(2025, 10);
      expect(m.year, 2025);
      expect(m.month, 10);
    });

    test('prevPath and nextPath computed correctly', () {
      final m = CalendarParser.emptyMonth(2025, 10);
      expect(m.prevPath, '/2025/9/1/');
      expect(m.nextPath, '/2025/11/1/');
    });
  });
}
