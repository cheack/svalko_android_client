import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/features/favorites/favorites_storage.dart';
import 'support/fake_string_box.dart';

// Build a ProviderContainer that uses an in-memory box instead of Hive.
ProviderContainer _container(FakeStringBox box) => ProviderContainer(
      overrides: [
        favoriteCommentsBoxProvider.overrideWithValue(box),
      ],
    );

// ---------------------------------------------------------------------------
// FavoriteComment serialisation
// ---------------------------------------------------------------------------

FavoriteComment _minimal() => FavoriteComment(
      id: 1,
      postId: 10,
      commentPage: 2,
      authorName: 'Alice',
      publishedAt: DateTime.utc(2024, 3, 15, 12, 0),
      addedAt: DateTime.utc(2024, 3, 15, 13, 0),
    );

FavoriteComment _full() => FavoriteComment(
      id: 2,
      postId: 20,
      commentPage: 3,
      authorName: 'Bob',
      publishedAt: DateTime.utc(2024, 4, 1, 9, 30),
      addedAt: DateTime.utc(2024, 4, 1, 10, 0),
      authorProfileUrl: 'https://example.com/bob',
      previewText: 'preview',
      textHtml: '<p>hello</p>',
      imageUrls: ['https://example.com/img.jpg'],
      videoUrls: ['https://example.com/vid.mp4'],
      isKum: true,
    );

void main() {
  group('FavoriteComment.toJson / fromJson', () {
    test('round-trips minimal comment', () {
      final c = _minimal();
      final restored = FavoriteComment.fromJson(c.toJson());

      expect(restored.id, c.id);
      expect(restored.postId, c.postId);
      expect(restored.commentPage, c.commentPage);
      expect(restored.authorName, c.authorName);
      expect(restored.publishedAt, c.publishedAt);
      expect(restored.addedAt, c.addedAt);
      expect(restored.authorProfileUrl, '');
      expect(restored.previewText, isNull);
      expect(restored.textHtml, isNull);
      expect(restored.imageUrls, isEmpty);
      expect(restored.videoUrls, isEmpty);
      expect(restored.isKum, isFalse);
    });

    test('round-trips full comment', () {
      final c = _full();
      final restored = FavoriteComment.fromJson(c.toJson());

      expect(restored.authorProfileUrl, c.authorProfileUrl);
      expect(restored.previewText, c.previewText);
      expect(restored.textHtml, c.textHtml);
      expect(restored.imageUrls, c.imageUrls);
      expect(restored.videoUrls, c.videoUrls);
      expect(restored.isKum, isTrue);
    });

    test('omits optional keys when empty/null/false', () {
      final json = _minimal().toJson();

      expect(json.containsKey('authorProfileUrl'), isFalse);
      expect(json.containsKey('previewText'), isFalse);
      expect(json.containsKey('textHtml'), isFalse);
      expect(json.containsKey('imageUrls'), isFalse);
      expect(json.containsKey('videoUrls'), isFalse);
      expect(json.containsKey('isKum'), isFalse);
    });

    test('includes optional keys when set', () {
      final json = _full().toJson();

      expect(json['authorProfileUrl'], 'https://example.com/bob');
      expect(json['textHtml'], '<p>hello</p>');
      expect(json['imageUrls'], ['https://example.com/img.jpg']);
      expect(json['videoUrls'], ['https://example.com/vid.mp4']);
      expect(json['isKum'], isTrue);
    });

    test('fromJson tolerates missing optional fields', () {
      final bare = {
        'id': 5,
        'postId': 50,
        'commentPage': 1,
        'authorName': 'Charlie',
        'publishedAt': '2024-01-01T00:00:00.000Z',
        'addedAt': '2024-01-01T01:00:00.000Z',
      };
      final c = FavoriteComment.fromJson(bare);

      expect(c.authorProfileUrl, '');
      expect(c.textHtml, isNull);
      expect(c.imageUrls, isEmpty);
      expect(c.videoUrls, isEmpty);
      expect(c.isKum, isFalse);
    });

    test('imageUrls / videoUrls survive JSON encode-decode cycle', () {
      final c = _full();
      final restored =
          FavoriteComment.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);

      expect(restored.imageUrls, c.imageUrls);
      expect(restored.videoUrls, c.videoUrls);
    });
  });

  // -------------------------------------------------------------------------
  // FavoriteCommentsNotifier — importList / exportList / toggle
  // -------------------------------------------------------------------------

  group('FavoriteCommentsNotifier', () {
    late FakeStringBox box;
    late ProviderContainer container;
    late FavoriteCommentsNotifier notifier;

    setUp(() {
      box = FakeStringBox();
      container = _container(box);
      notifier = container.read(favoriteCommentsProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('starts empty', () {
      expect(container.read(favoriteCommentsProvider), isEmpty);
    });

    test('add persists to box and updates state', () {
      notifier.add(_minimal());

      expect(container.read(favoriteCommentsProvider).length, 1);
      expect(box.values.length, 1);
      expect(
        FavoriteComment.fromJson(
            jsonDecode(box.values.first) as Map<String, dynamic>),
        predicate<FavoriteComment>((c) => c.id == 1),
      );
    });

    test('remove deletes from box and state', () {
      notifier.add(_minimal());
      notifier.remove(1);

      expect(container.read(favoriteCommentsProvider), isEmpty);
      expect(box.values, isEmpty);
    });

    test('toggle adds then removes', () {
      notifier.toggle(_minimal());
      expect(container.read(favoriteCommentsProvider).length, 1);

      notifier.toggle(_minimal());
      expect(container.read(favoriteCommentsProvider), isEmpty);
    });

    test('isFavorite returns correct value', () {
      expect(notifier.isFavorite(1), isFalse);
      notifier.add(_minimal());
      expect(notifier.isFavorite(1), isTrue);
    });

    test('importList skips duplicates', () {
      notifier.add(_minimal());
      final added = notifier.importList([_minimal().toJson()]);

      expect(added, 0);
      expect(container.read(favoriteCommentsProvider).length, 1);
    });

    test('importList adds new items', () {
      final added = notifier.importList([_minimal().toJson(), _full().toJson()]);

      expect(added, 2);
      expect(container.read(favoriteCommentsProvider).length, 2);
    });

    test('importList ignores malformed entries', () {
      final added = notifier.importList([
        _minimal().toJson(),
        {'bad': 'data'},
      ]);

      expect(added, 1);
    });

    test('exportList returns all items as JSON maps', () {
      notifier.add(_minimal());
      notifier.add(_full());

      final exported = notifier.exportList();
      expect(exported.length, 2);
      expect(exported.map((e) => e['id']), containsAll([1, 2]));
    });

    test('export → import round-trip preserves full data', () {
      notifier.add(_full());
      final exported = notifier.exportList();

      final box2 = FakeStringBox();
      final c2 = _container(box2);
      final n2 = c2.read(favoriteCommentsProvider.notifier);
      n2.importList(exported);

      final restored = c2.read(favoriteCommentsProvider).first;
      expect(restored.textHtml, '<p>hello</p>');
      expect(restored.imageUrls, ['https://example.com/img.jpg']);
      expect(restored.isKum, isTrue);
      c2.dispose();
    });

    test('state is sorted by addedAt descending', () {
      final older = FavoriteComment(
        id: 10,
        postId: 1,
        commentPage: 1,
        authorName: 'X',
        publishedAt: DateTime.utc(2024),
        addedAt: DateTime.utc(2024, 1, 1),
      );
      final newer = FavoriteComment(
        id: 11,
        postId: 1,
        commentPage: 1,
        authorName: 'Y',
        publishedAt: DateTime.utc(2024),
        addedAt: DateTime.utc(2024, 6, 1),
      );
      notifier.importList([older.toJson(), newer.toJson()]);
      final state = container.read(favoriteCommentsProvider);

      expect(state.first.id, 11);
      expect(state.last.id, 10);
    });
  });
}
