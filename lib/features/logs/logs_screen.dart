import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late final List<LogEntry> _entries;
  late final StreamSubscription<LogEntry> _sub;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = List.of(AppLogger.instance.entries);
    _sub = AppLogger.instance.stream.listen((entry) {
      setState(() => _entries.add(entry));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _clear() {
    AppLogger.instance.clear();
    setState(() => _entries.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить',
            onPressed: _clear,
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(child: Text('Нет событий'))
          : ListView.builder(
              controller: _scrollController,
              itemCount: _entries.length,
              itemBuilder: (context, i) => _EntryTile(entry: _entries[i]),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, icon) = switch (entry.level) {
      LogLevel.cache => (Colors.green.shade700, Icons.storage_outlined),
      LogLevel.network => (cs.primary, Icons.cloud_download_outlined),
      LogLevel.error => (cs.error, Icons.error_outline),
      LogLevel.info => (cs.onSurfaceVariant, Icons.info_outline),
    };
    final time = _fmt(entry.time);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time  ${entry.message}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
                if (entry.detail != null && entry.detail!.isNotEmpty)
                  Text(
                    entry.detail!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}.${dt.millisecond.toString().padLeft(3, '0')}';

  String _p(int v) => v.toString().padLeft(2, '0');
}
