import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/crash_reporter.dart';
import '../../data/svalko_api.dart';
import '../notifications/notification_service.dart';
import 'news_check_service.dart';

abstract final class NewsBackgroundWorker {
  static const uniqueName = 'svalko_news_periodic_check';
  static const taskName = 'svalko_news_check';
  static const interval = Duration(hours: 1);

  static Future<void> initialize() =>
      Workmanager().initialize(newsBackgroundCallbackDispatcher);

  static Future<void> updateSchedule({required bool enabled}) async {
    if (!enabled) {
      await Workmanager().cancelByUniqueName(uniqueName);
      return;
    }

    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: interval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}

@pragma('vm:entry-point')
void newsBackgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != NewsBackgroundWorker.taskName) return true;

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();
      final settings = await Hive.openBox<String>('settings');
      final checker = NewsCheckService(api: SvalkoApi(), settingsBox: settings);
      if (!checker.notificationsEnabled) return true;

      final notifications = NotificationService.instance;
      await notifications.initialize();
      if (!await notifications.areNotificationsEnabled()) return true;

      final newPosts = await checker.checkNewPosts();
      await notifications.showNewPosts(newPosts);
      return true;
    } catch (e, st) {
      CrashReporter.instance.report(e, st);
      return false;
    }
  });
}
