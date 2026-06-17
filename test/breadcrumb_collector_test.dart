import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/breadcrumb_collector.dart';

void main() {
  group('BreadcrumbCollector', () {
    test('snapshot is empty initially', () {
      final collector = BreadcrumbCollector();
      expect(collector.snapshot(), isEmpty);
    });

    test('records added breadcrumbs in order', () {
      final collector = BreadcrumbCollector();
      collector.add('first');
      collector.add('second');
      final snap = collector.snapshot();
      expect(snap.map((b) => b['message']), ['first', 'second']);
    });

    test('evicts oldest entry when capacity is exceeded', () {
      final collector = BreadcrumbCollector(capacity: 3);
      collector.add('a');
      collector.add('b');
      collector.add('c');
      collector.add('d');
      final messages = collector.snapshot().map((b) => b['message']);
      expect(messages, ['b', 'c', 'd']);
    });

    test('clear removes all entries', () {
      final collector = BreadcrumbCollector();
      collector.add('x');
      collector.clear();
      expect(collector.snapshot(), isEmpty);
    });

    test('addNavigation sets type and message', () {
      final collector = BreadcrumbCollector();
      collector.addNavigation('/', '/post');
      final entry = collector.snapshot().first;
      expect(entry['type'], 'navigation');
      expect(entry['message'], '/ → /post');
    });

    test('addHttp includes status and duration', () {
      final collector = BreadcrumbCollector();
      collector.addHttp('GET', 'https://svalko.org/', statusCode: 200, durationMs: 150);
      final entry = collector.snapshot().first;
      expect(entry['type'], 'http');
      expect(entry['message'], 'GET https://svalko.org/');
      expect((entry['data'] as Map)['status'], 200);
      expect((entry['data'] as Map)['duration_ms'], 150);
    });

    test('addHttp error sets error flag', () {
      final collector = BreadcrumbCollector();
      collector.addHttp('POST', 'https://svalko.org/api', isError: true);
      final data = collector.snapshot().first['data'] as Map;
      expect(data['error'], true);
    });

    test('snapshot does not include null data when no extra fields', () {
      final collector = BreadcrumbCollector();
      collector.add('plain');
      final entry = collector.snapshot().first;
      expect(entry.containsKey('data'), isFalse);
    });
  });
}
