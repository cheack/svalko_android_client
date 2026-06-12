import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/models/feed_source.dart';

void main() {
  group('DateFeed', () {
    test('normalizes date paths with leading zeroes', () {
      expect(DateFeed.normalizePath('/2026/04/09/'), '/2026/4/9/');
    });

    test('fromDateTime uses normalized path', () {
      final feed = DateFeed.fromDateTime(DateTime(2026, 4, 9));
      expect(feed.path, '/2026/4/9/');
    });
  });
}
