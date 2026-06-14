import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract final class AppNotificationChannels {
  static const news = AndroidNotificationChannel(
    'svalko_news',
    'Новые посты',
    description: 'Уведомления о новых постах на Свалке',
    importance: Importance.defaultImportance,
  );
}
