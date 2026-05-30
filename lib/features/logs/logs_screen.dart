import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  Future<void> _share() async {
    final buf = StringBuffer();

    // Device & app info header
    final packageInfo = await PackageInfo.fromPlatform();
    buf.writeln('app: ${packageInfo.appName} ${packageInfo.version}+${packageInfo.buildNumber}');
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      buf.writeln('device: ${a.manufacturer} ${a.model} (Android ${a.version.release}, SDK ${a.version.sdkInt})');
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      buf.writeln('device: ${i.name} ${i.systemName} ${i.systemVersion}');
    } else {
      buf.writeln('device: ${Platform.operatingSystem}');
    }
    buf.writeln('─' * 40);

    for (final e in _entries) {
      final time =
          '${_p(e.time.hour)}:${_p(e.time.minute)}:${_p(e.time.second)}.${e.time.millisecond.toString().padLeft(3, '0')}';
      final level = e.level.name.toUpperCase().padRight(7);
      buf.writeln('$time $level ${e.message}');
      if (e.detail != null && e.detail!.isNotEmpty) {
        buf.writeln('        ${e.detail}');
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/svalko_logs.txt');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path)], subject: 'svalko logs');
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Поделиться',
            onPressed: _entries.isEmpty ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Очистить',
            onPressed: _entries.isEmpty ? null : _clear,
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
