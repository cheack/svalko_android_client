import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/result.dart';
import '../../../data/parsers/calendar_parser.dart';
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

  static const _firstYear = 2003;
  static const _firstMonth = 8; // August 2003

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final maxMonth = _calendar.year == now.year ? now.month : 12;
    final minMonth = _calendar.year == _firstYear ? _firstMonth : 1;
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + box.size.height, offset.dx + box.size.width, 0),
      items: List.generate(maxMonth - minMonth + 1, (i) => minMonth + i)
          .map((m) => PopupMenuItem(
                value: m,
                child: Text(_monthNames[m],
                    style: m == _calendar.month
                        ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                        : null),
              ))
          .toList(),
    );
    if (selected != null && selected != _calendar.month) {
      _changeMonth(CalendarParser.monthPath(_calendar.year, selected));
    }
  }

  Future<void> _pickYear(BuildContext context) async {
    final now = DateTime.now();
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + box.size.height, offset.dx + box.size.width, 0),
      items: List.generate(now.year - _firstYear + 1, (i) => _firstYear + i)
          .map((y) => PopupMenuItem(
                value: y,
                child: Text('$y',
                    style: y == _calendar.year
                        ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                        : null),
              ))
          .toList(),
    );
    if (selected != null && selected != _calendar.year) {
      final now2 = DateTime.now();
      var month = _calendar.month;
      if (selected == now2.year && month > now2.month) month = now2.month;
      if (selected == _firstYear && month < _firstMonth) month = _firstMonth;
      _changeMonth(CalendarParser.monthPath(selected, month));
    }
  }

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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Builder(builder: (ctx) => GestureDetector(
                                onTap: () => _pickMonth(ctx),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_monthNames[c.month], style: theme.textTheme.titleMedium),
                                    Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.outline),
                                  ],
                                ),
                              )),
                              const SizedBox(width: 4),
                              Builder(builder: (ctx) => GestureDetector(
                                onTap: () => _pickYear(ctx),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${c.year}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                                    Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                                  ],
                                ),
                              )),
                            ],
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

    final brandColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final onBrandColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    if (isSelected) {
      bg = brandColor;
      textColor = onBrandColor;
    } else if (hasLink && inMonth) {
      bg = brandColor.withValues(alpha: 0.25);
      textColor = onBrandColor;
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
