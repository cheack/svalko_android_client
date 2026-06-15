import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_tile_helpers.dart';

import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../data/svalko_api.dart';
import '../news/news_check_service.dart';
import '../news/news_item.dart';
import '../notifications/notification_service.dart';

class DebugNewsTile extends ConsumerWidget {
  const DebugNewsTile({super.key});

  static const _counts = [1, 2, 3, 10];

  static final _mediaScenarios = <({String label, Uri? imageUrl, String html})>[
    (
      label: 'Текст',
      imageUrl: null,
      html: '<p>Текстовый пост без медиа-вложений.</p>',
    ),
    (
      label: 'Фото (JPEG)',
      imageUrl: Uri.parse('https://picsum.photos/id/10/640/360.jpg'),
      html: '<img src="https://picsum.photos/id/10/640/360.jpg" />',
    ),
    (
      label: 'Гифка',
      imageUrl: Uri.parse(
        'https://upload.wikimedia.org/wikipedia/commons/2/2c/'
        'Rotating_earth_%28large%29.gif',
      ),
      html: '<img src="https://upload.wikimedia.org/wikipedia/commons/2/2c/'
          'Rotating_earth_%28large%29.gif" />',
    ),
    (
      label: 'Видео (без превью)',
      imageUrl: null,
      html: '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"'
          ' width="560" height="315"></iframe>',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        debugSubHeader('По количеству (pipeline, обновляет lastSeenId)'),
        for (final count in _counts)
          debugTile(
            title: '$count ${_postWord(count)}',
            onPressed: () => _runPipeline(ref, count),
          ),
        debugSubHeader('По типу медиа (напрямую → showNewPosts)'),
        for (final s in _mediaScenarios)
          debugTile(
            title: s.label,
            onPressed: () => _showMediaPost(ref, s.label, s.imageUrl, s.html),
          ),
      ],
    );
  }

  Future<void> _runPipeline(WidgetRef ref, int count) async {
    final box = ref.read(settingsBoxProvider);
    final lastSeenId =
        int.tryParse(box.get(NewsSettingsKeys.lastSeenPostId) ?? '') ?? 1000000;
    final ids = List.generate(count, (i) => lastSeenId + count - i);
    final fakeRss =
        '<rss><channel>'
        '${ids.map((id) => '<item>'
            '<title>Тестовый пост #$id</title>'
            '<link>https://svalko.org/$id.html</link>'
            '<guid>https://svalko.org/$id.html</guid>'
            '<author>no-reply@svalko.org (debug)</author>'
            '</item>').join()}'
        '</channel></rss>';

    final items = await NewsCheckService(
      api: _FakeRssApi(fakeRss),
      settingsBox: box,
    ).checkNewPosts();
    if (items.isNotEmpty) await NotificationService.instance.showNewPosts(items);
  }

  Future<void> _showMediaPost(
    WidgetRef ref,
    String label,
    Uri? imageUrl,
    String html,
  ) async {
    final box = ref.read(settingsBoxProvider);
    final baseId =
        int.tryParse(box.get(NewsSettingsKeys.lastSeenPostId) ?? '') ?? 1000000;
    final id = baseId + 1;
    await NotificationService.instance.showNewPosts([
      NewsItem(
        id: id,
        title: 'Тест: $label',
        author: 'debug',
        publishedAt: DateTime.now(),
        link: Uri.parse('https://svalko.org/$id.html'),
        descriptionHtml: html,
        imageUrl: imageUrl,
      ),
    ]);
  }

  static String _postWord(int n) => switch (n % 10) {
    1 => 'пост',
    2 || 3 || 4 => 'поста',
    _ => 'постов',
  };
}

class _FakeRssApi extends SvalkoApi {
  _FakeRssApi(this._xml);
  final String _xml;

  @override
  Future<Result<String, AppError>> fetchNewsRss() async => Ok(_xml);
}
