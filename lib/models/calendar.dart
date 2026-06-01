import 'package:flutter/foundation.dart';

@immutable
class CalendarDay {
  const CalendarDay({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    this.path,
  });

  final int day;
  final bool isCurrentMonth;
  final bool isToday;
  final String? path; // null = no posts on this day
}

@immutable
class CalendarMonth {
  const CalendarMonth({
    required this.year,
    required this.month,
    required this.days,
    this.prevPath,
    this.nextPath,
  });

  final int year;
  final int month;
  final List<CalendarDay> days;
  final String? prevPath;
  final String? nextPath;
}
