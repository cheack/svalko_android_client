import 'dart:async';

enum LogLevel { info, cache, network, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.detail,
  });

  final DateTime time;
  final LogLevel level;
  final String message;
  final String? detail;
}

class AppLogger {
  static final AppLogger instance = AppLogger._();
  AppLogger._();

  static const _maxEntries = 500;

  final _entries = <LogEntry>[];
  final _controller = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(LogLevel level, String message, {String? detail}) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
      detail: detail,
    );
    if (_entries.length >= _maxEntries) _entries.removeAt(0);
    _entries.add(entry);
    _controller.add(entry);
  }

  void info(String msg, {String? detail}) =>
      log(LogLevel.info, msg, detail: detail);
  void cache(String msg, {String? detail}) =>
      log(LogLevel.cache, msg, detail: detail);
  void network(String msg, {String? detail}) =>
      log(LogLevel.network, msg, detail: detail);
  void error(String msg, {String? detail}) =>
      log(LogLevel.error, msg, detail: detail);

  void clear() => _entries.clear();
}
