import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/settings_storage.dart';
import '../../data/svalko_api.dart';
import 'news_background_worker.dart';
import 'news_check_service.dart';

class NewsNotificationsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(settingsBoxProvider);
    return box.get(NewsSettingsKeys.notificationsEnabled) == 'true';
  }

  Future<void> set(bool value) async {
    final box = ref.read(settingsBoxProvider);
    state = value;
    await box.put(NewsSettingsKeys.notificationsEnabled, value.toString());
    if (value) {
      unawaited(_primeLastSeen(box));
    }
    if (Platform.isAndroid) {
      await NewsBackgroundWorker.updateSchedule(enabled: value);
    }
  }

  Future<void> _primeLastSeen(Box<String> box) => NewsCheckService(
        api: SvalkoApi(),
        settingsBox: box,
      ).checkNewPosts();
}

final newsNotificationsProvider =
    NotifierProvider<NewsNotificationsNotifier, bool>(
      NewsNotificationsNotifier.new,
    );
