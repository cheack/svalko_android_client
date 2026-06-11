import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/result.dart';
import '../../../core/settings_storage.dart';
import '../../../data/parsers/calendar_parser.dart';
import '../../../models/calendar.dart';
import '../../../models/feed_source.dart';
import '../feed_controller.dart';

const _monthNames = [
  '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
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

    final now = _effectiveNow;
    final tooNew = _calendar.year > now.year ||
        (_calendar.year == now.year && _calendar.month > now.month);
    if (tooNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _changeMonth(CalendarParser.monthPath(now.year, now.month));
      });
    }
  }

  String? get _selectedPath => ref.read(calendarStateProvider).selectedPath;

  static const _firstYear = 2003;
  static const _firstMonth = 8; // August 2003

  DateTime get _effectiveNow {
    final now = DateTime.now();
    final isTa = ref.read(siteModeProvider) == SiteMode.taSvalko;
    return isTa ? DateTime(now.year - 10, now.month, now.day) : now;
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = _effectiveNow;
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
    final now = _effectiveNow;
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
      final now2 = _effectiveNow;
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
    Navigator.of(context).pop(DateFeed(
      path: day.path!,
      label: DateFeed.labelFor(day.day, _calendar.month, _calendar.year),
    ));
  }

  CalendarDay _clampDay(CalendarDay day, DateTime? limit) {
    if (limit == null) return day;
    if (!day.isCurrentMonth) return day;
    final pastLimit = _calendar.year > limit.year ||
        (_calendar.year == limit.year && _calendar.month > limit.month) ||
        (_calendar.year == limit.year && _calendar.month == limit.month && day.day > limit.day);
    return pastLimit
        ? CalendarDay(day: day.day, isCurrentMonth: day.isCurrentMonth, isToday: day.isToday)
        : day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _calendar;
    final selectedPath = _selectedPath;
    final isTa = ref.read(siteModeProvider) == SiteMode.taSvalko;
    final limit = isTa ? _effectiveNow : null;
    final nextBlocked = limit != null && (c.year > limit.year ||
        (c.year == limit.year && c.month >= limit.month));

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
                  onPressed: (_loading || c.nextPath == null || nextBlocked)
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
                  .map((day) {
                        final d = _clampDay(day, limit);
                        return _DayCell(
                          day: d,
                          isSelected: d.path != null && d.path == selectedPath,
                          onTap: () => _selectDay(d),
                        );
                      })
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
