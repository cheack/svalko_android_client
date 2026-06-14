import 'package:flutter/material.dart';

import '../../core/crash_reporter.dart';

class DebugCrashTile extends StatelessWidget {
  const DebugCrashTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _subHeader('Crash reporter'),
        Builder(
          builder: (context) => _tile(
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
          builder: (context) => _tile(
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

  Widget _subHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ),
  );

  Widget _tile({required String title, required VoidCallback onPressed}) =>
      ListTile(
        title: Text(title),
        trailing: TextButton(onPressed: onPressed, child: const Text('Отправить')),
      );
}
