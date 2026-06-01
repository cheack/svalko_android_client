import 'package:html/dom.dart';
import '../../models/calendar.dart';

final _dayPathRe = RegExp(r'/(\d{4})/(\d+)/\d+/?');

abstract final class CalendarParser {
  static CalendarMonth? parse(Document doc) {
    final div = doc.querySelector('#calendar');
    if (div == null) return null;

    // Determine current month/year from the first in-month day link.
    // The site's caption nav links are buggy (e.g. month 0), so we compute
    // prev/next ourselves from the parsed year/month.
    int? year, month;
    for (final td in div.querySelectorAll('tbody td')) {
      if (td.classes.contains('cd')) continue;
      final href = td.querySelector('a')?.attributes['href'] ?? '';
      final m = _dayPathRe.firstMatch(href);
      if (m != null) {
        year = int.parse(m.group(1)!);
        month = int.parse(m.group(2)!);
        break;
      }
    }

    if (year == null || month == null) return null;

    final days = <CalendarDay>[];
    for (final td in div.querySelectorAll('tbody td')) {
      final isCurrentMonth = !td.classes.contains('cd');
      final a = td.querySelector('a');
      final label = (a ?? td.querySelector('span'))?.text.trim() ?? '';
      final day = int.tryParse(label);
      if (day == null) continue;
      days.add(CalendarDay(
        day: day,
        isCurrentMonth: isCurrentMonth,
        isToday: false,
        path: a?.attributes['href'],
      ));
    }

    final now = DateTime.now();
    final nextY = month == 12 ? year + 1 : year;
    final nextM = month == 12 ? 1 : month + 1;
    final nextInFuture =
        nextY > now.year || (nextY == now.year && nextM > now.month);

    return CalendarMonth(
      year: year,
      month: month,
      days: days,
      prevPath: monthPath(year, month - 1),
      nextPath: nextInFuture ? null : monthPath(year, month + 1),
    );
  }

  static String monthPath(int year, int month) {
    if (month == 0) return '/${year - 1}/12/1/';
    if (month == 13) return '/${year + 1}/1/1/';
    return '/$year/$month/1/';
  }

  static CalendarMonth emptyMonth(int year, int month) => CalendarMonth(
        year: year,
        month: month,
        days: const [],
        prevPath: monthPath(year, month - 1),
        nextPath: monthPath(year, month + 1),
      );
}
