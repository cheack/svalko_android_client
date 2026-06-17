import 'dart:collection';
import 'package:flutter/widgets.dart';

enum BreadcrumbType { navigation, http, info }

class Breadcrumb {
  const Breadcrumb({
    required this.type,
    required this.message,
    required this.timestamp,
    this.data,
  });

  final BreadcrumbType type;
  final String message;
  final DateTime timestamp;
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        if (data != null) 'data': data,
      };
}

class BreadcrumbCollector {
  BreadcrumbCollector({int capacity = 30}) : _capacity = capacity;

  static final instance = BreadcrumbCollector();

  final int _capacity;
  final _queue = ListQueue<Breadcrumb>();

  late final NavigatorObserver navigatorObserver =
      _BreadcrumbNavigatorObserver(this);

  void add(
    String message, {
    BreadcrumbType type = BreadcrumbType.info,
    Map<String, Object?>? data,
  }) {
    if (_queue.length >= _capacity) _queue.removeFirst();
    _queue.addLast(Breadcrumb(
      type: type,
      message: message,
      timestamp: DateTime.now(),
      data: data,
    ));
  }

  void addNavigation(String? from, String? to) {
    add(
      '${from ?? '?'} → ${to ?? '?'}',
      type: BreadcrumbType.navigation,
    );
  }

  void addHttp(
    String method,
    String url, {
    int? statusCode,
    int? durationMs,
    bool isError = false,
  }) {
    add(
      '$method $url',
      type: BreadcrumbType.http,
      data: {
        ?'status': statusCode,
        ?'duration_ms': durationMs,
        if (isError) 'error': true,
      },
    );
  }

  List<Map<String, Object?>> snapshot() =>
      _queue.map((b) => b.toJson()).toList();

  void clear() => _queue.clear();
}

class _BreadcrumbNavigatorObserver extends NavigatorObserver {
  _BreadcrumbNavigatorObserver(this._collector);

  final BreadcrumbCollector _collector;

  @override
  void didPush(Route route, Route? previousRoute) {
    _collector.addNavigation(
      previousRoute?.settings.name,
      route.settings.name,
    );
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _collector.addNavigation(
      route.settings.name,
      previousRoute?.settings.name,
    );
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _collector.addNavigation(
      oldRoute?.settings.name,
      newRoute?.settings.name,
    );
  }
}
