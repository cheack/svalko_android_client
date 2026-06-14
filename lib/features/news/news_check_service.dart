import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/crash_reporter.dart';
import '../../core/result.dart';
import '../../data/svalko_api.dart';
import 'news_item.dart';
import 'rss_news_parser.dart';

abstract final class NewsSettingsKeys {
  static const notificationsEnabled = 'news_notifications_enabled';
  static const lastSeenPostId = 'news_last_seen_post_id';
  static const lastCheckAt = 'news_last_check_at';
}

class NewsCheckService {
  const NewsCheckService({
    required SvalkoApi api,
    required Box<String> settingsBox,
  }) : _api = api,
       _settingsBox = settingsBox;

  final SvalkoApi _api;
  final Box<String> _settingsBox;

  bool get notificationsEnabled =>
      _settingsBox.get(NewsSettingsKeys.notificationsEnabled) == 'true';

  Future<void> setNotificationsEnabled(bool enabled) => _settingsBox.put(
    NewsSettingsKeys.notificationsEnabled,
    enabled.toString(),
  );

  Future<List<NewsItem>> checkNewPosts() async {
    final result = await _api.fetchNewsRss();
    final checkedAt = DateTime.now().toIso8601String();
    await _settingsBox.put(NewsSettingsKeys.lastCheckAt, checkedAt);

    final xml = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (xml == null) return const [];

    final List<NewsItem> items;
    try {
      items = RssNewsParser.parse(xml);
    } catch (e, st) {
      CrashReporter.instance.report(e, st);
      return const [];
    }
    if (items.isEmpty) return const [];

    final newestId = items.map((i) => i.id).reduce((a, b) => a > b ? a : b);
    final lastSeenId = int.tryParse(
      _settingsBox.get(NewsSettingsKeys.lastSeenPostId) ?? '',
    );

    if (lastSeenId == null) {
      await _settingsBox.put(
        NewsSettingsKeys.lastSeenPostId,
        newestId.toString(),
      );
      return const [];
    }

    final newItems = items.where((item) => item.id > lastSeenId).toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    if (newestId > lastSeenId) {
      await _settingsBox.put(
        NewsSettingsKeys.lastSeenPostId,
        newestId.toString(),
      );
    }
    return newItems;
  }
}
