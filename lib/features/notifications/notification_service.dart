import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';
import '../news/news_item.dart';
import 'notification_channels.dart';

typedef PostNotificationTap = void Function(int postId);

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  static const _newsSummaryNotificationId = 1000000001;
  static const _notificationChannel = MethodChannel('org.svalko/notifications');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  PostNotificationTap? _onPostTap;

  Future<void> initialize({PostNotificationTap? onPostTap}) async {
    _onPostTap = onPostTap ?? _onPostTap;
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_notification');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    await ensureChannels();
    _initialized = true;
  }

  Future<int?> getLaunchPostId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final payload = details?.notificationResponse?.payload;
    return _postIdFromPayload(payload);
  }

  Future<void> ensureChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(AppNotificationChannels.news);
  }

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> requestNotificationsPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    await _notificationChannel.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> showNewPosts(List<NewsItem> items) async {
    if (items.isEmpty) return;
    await initialize();

    final imagePath = await _downloadFirstImage(items);
    final title = items.length == 1
        ? 'Новый пост'
        : 'Новых постов: ${items.length}';
    final body = items.length == 1
        ? items.first.notificationBody
        : items.take(3).map((i) => i.notificationBody).join('\n');

    await _plugin.show(
      id: items.length == 1 ? items.first.id : _newsSummaryNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          AppNotificationChannels.news.id,
          AppNotificationChannels.news.name,
          channelDescription: AppNotificationChannels.news.description,
          styleInformation: imagePath == null
              ? BigTextStyleInformation(body)
              : BigPictureStyleInformation(
                  FilePathAndroidBitmap(imagePath),
                  contentTitle: title,
                  summaryText: body,
                  largeIcon: FilePathAndroidBitmap(imagePath),
                  hideExpandedLargeIcon: true,
                ),
          largeIcon: imagePath == null
              ? null
              : FilePathAndroidBitmap(imagePath),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: items.length == 1 ? 'post:${items.first.id}' : null,
    );
  }

  Future<String?> _downloadFirstImage(List<NewsItem> items) async {
    final imageUrl = items.map((i) => i.imageUrl).whereType<Uri>().firstOrNull;
    if (imageUrl == null) return null;

    try {
      final response = await http
          .get(imageUrl, headers: {'User-Agent': Config.userAgent})
          .timeout(Config.receiveTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/svalko_news_${imageUrl.pathSegments.last}',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final postId = _postIdFromPayload(response.payload);
    if (postId != null) _onPostTap?.call(postId);
  }

  int? _postIdFromPayload(String? payload) {
    if (payload == null) return null;
    final match = RegExp(r'^post:(\d+)$').firstMatch(payload);
    return int.tryParse(match?.group(1) ?? '');
  }
}
