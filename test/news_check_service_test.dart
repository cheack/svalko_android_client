import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/result.dart';
import 'package:svalko_client/data/svalko_api.dart';
import 'package:svalko_client/features/news/news_check_service.dart';

import 'support/fake_string_box.dart';

class _FakeSvalkoApi extends SvalkoApi {
  _FakeSvalkoApi(Iterable<Result<String, AppError>> responses)
      : _responses = Queue.of(responses);

  final Queue<Result<String, AppError>> _responses;

  @override
  Future<Result<String, AppError>> fetchNewsRss() async =>
      _responses.removeFirst();
}

void main() {
  group('NewsCheckService', () {
    test('initial check stores newest id and returns no notifications', () async {
      final box = FakeStringBox();
      final service = NewsCheckService(
        api: _FakeSvalkoApi([Ok(_rss([102, 101]))]),
        settingsBox: box,
      );

      final items = await service.checkNewPosts();

      expect(items, isEmpty);
      expect(box.get(NewsSettingsKeys.lastSeenPostId), '102');
      expect(box.get(NewsSettingsKeys.lastCheckAt), isNotNull);
    });

    test('returns only posts newer than last seen id', () async {
      final box = FakeStringBox();
      await box.put(NewsSettingsKeys.lastSeenPostId, '102');
      final service = NewsCheckService(
        api: _FakeSvalkoApi([Ok(_rss([104, 103, 102, 101]))]),
        settingsBox: box,
      );

      final items = await service.checkNewPosts();

      expect(items.map((i) => i.id), [104, 103]);
      expect(box.get(NewsSettingsKeys.lastSeenPostId), '104');
    });
  });
}

String _rss(List<int> ids) {
  final items = ids.map((id) => '''
    <item>
      <title>post $id</title>
      <link>http://svalko.org/$id.html</link>
      <guid>http://svalko.org/$id.html</guid>
    </item>
''').join();

  return '<rss><channel>$items</channel></rss>';
}
