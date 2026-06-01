import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/result.dart';
import '../../../models/calendar.dart';
import '../../../models/feed_source.dart';
import '../feed_controller.dart';

const _monthNames = [
  '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

const _monthNamesGen = [
  '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

class CalendarSheet extends ConsumerStatefulWidget {
  const CalendarSheet({super.key, required this.fallbackMonth});

  /// Used only if the provider has no saved month yet.
  final CalendarMonth fallbackMonth;

  @override
  ConsumerState<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends ConsumerState<CalendarSheet> {
  late CalendarMonth _calendar;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(calendarStateProvider);
    _calendar = saved.month ?? widget.fallbackMonth;
  }

  String? get _selectedPath => ref.read(calendarStateProvider).selectedPath;

  Future<void> _changeMonth(String? path) async {
    if (path == null || _loading) return;
    final repo = ref.read(repositoryProvider);
    final cached = repo.getCachedCalendar(path);
    if (cached != null) {
      setState(() => _calendar = cached);
      ref.read(calendarStateProvider.notifier).update(
            (s) => (month: cached, selectedPath: s.selectedPath),
          );
      return;
    }
    setState(() => _loading = true);
    final result = await repo.getCalendar(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result case Ok(:final value)) {
        _calendar = value;
        ref.read(calendarStateProvider.notifier).update(
              (s) => (month: value, selectedPath: s.selectedPath),
            );
      }
    });
  }

  void _selectDay(CalendarDay day) {
    if (day.path == null) return;
    ref.read(calendarStateProvider.notifier).update(
          (s) => (month: _calendar, selectedPath: day.path),
        );
    final label = '${day.day} ${_monthNamesGen[_calendar.month]} ${_calendar.year}';
    Navigator.of(context).pop(DateFeed(path: day.path!, label: label));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _calendar;
    final selectedPath = _selectedPath;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _loading ? null : () => _changeMonth(c.prevPath),
                ),
                Expanded(
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '${_monthNames[c.month]} ${c.year}',
                            style: theme.textTheme.titleMedium,
                          ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_loading || c.nextPath == null)
                      ? null
                      : () => _changeMonth(c.nextPath),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: c.days
                  .map((day) => _DayCell(
                        day: day,
                        isSelected: day.path != null && day.path == selectedPath,
                        onTap: () => _selectDay(day),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isSelected, required this.onTap});

  final CalendarDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLink = day.path != null;
    final inMonth = day.isCurrentMonth;

    Color? bg;
    Color textColor;

    if (isSelected) {
      bg = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (hasLink && inMonth) {
      bg = theme.colorScheme.primaryContainer.withValues(alpha: 0.5);
      textColor = theme.colorScheme.onPrimaryContainer;
    } else {
      textColor = inMonth
          ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
          : theme.colorScheme.onSurface.withValues(alpha: 0.2);
    }

    return GestureDetector(
      onTap: hasLink ? onTap : null,
      child: Container(
        decoration: bg != null
            ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4))
            : null,
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: hasLink && inMonth ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
