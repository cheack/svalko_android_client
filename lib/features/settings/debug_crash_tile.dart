import 'package:flutter/material.dart';

import '../../core/crash_reporter.dart';
import 'debug_tile_helpers.dart';

class DebugCrashTile extends StatelessWidget {
  const DebugCrashTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        debugSubHeader('Crash reporter'),
        Builder(
          builder: (context) => debugTile(
            title: 'Тестовый exception',
            onPressed: () async {
              final sent = await CrashReporter.instance.report(
                Exception('debug test exception'),
                StackTrace.current,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(sent
                    ? 'Отправлено'
                    : 'Не отправлено — CRASH_HANDLER_URL или APP_SECRET не заданы'),
              ));
            },
          ),
        ),
        Builder(
          builder: (context) => debugTile(
            title: 'Настоящий краш',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Тестовый краш'),
                  content: const Text(
                    'Приложение бросит необработанное исключение — '
                    'оно пройдёт через runZonedGuarded и FlutterError.onError. '
                    'В дебаге увидишь красный экран, в релизе — краш с репортом.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Крашнуть'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              Future.microtask(() => throw StateError('debug crash test'));
            },
          ),
        ),
      ],
    );
  }

}
