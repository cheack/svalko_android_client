import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/crash_reporter.dart';
import 'core/encoding.dart';
import 'core/settings_storage.dart';
import 'data/svalko_api.dart';
import 'features/favorites/favorites_storage.dart';
import 'features/feed/feed_controller.dart';
import 'features/news/news_background_worker.dart';
import 'features/news/news_check_service.dart';
import 'features/notifications/notification_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (details.silent) return;
        CrashReporter.instance
            .report(details.exception, details.stack ?? StackTrace.empty);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        CrashReporter.instance.report(error, stack, fatal: true);
        return true;
      };

      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.subscribeToTopic('all');
      FirebaseMessaging.onMessage.listen(
        (msg) => NotificationService.instance.showPush(msg),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(_showPushDialog);
      messaging.getInitialMessage().then((msg) {
        if (msg != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showPushDialog(msg),
          );
        }
      });

      await CrashReporter.instance.init();

      await Hive.initFlutter();
      final settings = await Hive.openBox<String>('settings');
      final votes = await Hive.openBox<String>('votes');

      final favorites = await Hive.openBox<String>('favorites');
      final favoriteComments = await Hive.openBox<String>('favorites_comments');
      final favoritesDarkSide = await Hive.openBox<String>('favorites_dark_side');
      final calendarCache = await Hive.openBox<String>('calendar');

      final cacheDir = await getApplicationCacheDirectory();
      final cacheStore = FileCacheStore('${cacheDir.path}/http_cache');

      String mynameCookie = settings.get('mynameCookie') ?? '';
      if (mynameCookie.isEmpty) {
        final author = settings.get('comment_author') ?? '';
        if (author.isNotEmpty) {
          final encoded = await encodeQueryWin1251(author);
          mynameCookie = 'myname=$encoded';
          settings.put('mynameCookie', mynameCookie);
        }
      }

      int? launchPostId;
      try {
        await NotificationService.instance.initialize(
          onPostTap: _openPostFromNotification,
        );
        launchPostId = await NotificationService.instance.getLaunchPostId();
      } catch (e, s) {
        CrashReporter.instance.report(e, s);
      }

      if (Platform.isAndroid) {
        try {
          await NewsBackgroundWorker.initialize();
          await NewsBackgroundWorker.updateSchedule(
            enabled:
                settings.get(NewsSettingsKeys.notificationsEnabled) == 'true',
          );
        } catch (e, s) {
          CrashReporter.instance.report(e, s);
        }
      }

      runApp(
        ProviderScope(
          overrides: [
          apiProvider.overrideWithValue(
            SvalkoApi(
              cacheStore: cacheStore,
              mynameCookie: mynameCookie,
            ),
          ),
            settingsBoxProvider.overrideWithValue(settings),
            votesBoxProvider.overrideWithValue(votes),
            favoritesBoxProvider.overrideWithValue(favorites),
            favoriteCommentsBoxProvider.overrideWithValue(favoriteComments),
            favoritesDarkSideBoxProvider.overrideWithValue(favoritesDarkSide),
            calendarBoxProvider.overrideWithValue(calendarCache),
          ],
          child: const SvalkoApp(),
        ),
      );

      if (launchPostId != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openPostFromNotification(launchPostId!),
        );
      }

      _initDeepLinks();
    },
    (error, stack) => CrashReporter.instance.report(error, stack, fatal: true),
  );
}

void _showPushDialog(RemoteMessage message) {
  final text = message.data['message'] as String?;
  if (text == null || text.isEmpty) return;
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// Dark side has no comments/post-detail page, so `/post` can't work there —
// notifications and deep links always point at a normal-site post.
void _ensureNormalSiteMode(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(siteModeProvider) == SiteMode.darkSide) {
    container.read(siteModeProvider.notifier).set(SiteMode.svalko);
  }
}

void _openPostFromNotification(int postId) {
  final context = navigatorKey.currentContext;
  final navigator = navigatorKey.currentState;
  if (context == null || navigator == null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openPostFromNotification(postId),
    );
    return;
  }
  _ensureNormalSiteMode(context);
  navigator.pushNamed('/post', arguments: postId);
}

void _initDeepLinks() {
  final appLinks = AppLinks();

  appLinks.getInitialLink().then((uri) {
    if (uri != null) _handleDeepLink(uri);
  });

  appLinks.uriLinkStream.listen(_handleDeepLink);
}

void _handleDeepLink(Uri uri) {
  final match = RegExp(r'^/(\d+)\.html$').firstMatch(uri.path);
  if (match == null) return;
  final postId = int.tryParse(match.group(1)!);
  if (postId == null) return;
  final context = navigatorKey.currentContext;
  if (context == null) return;
  _ensureNormalSiteMode(context);
  navigatorKey.currentState?.pushNamed('/post', arguments: postId);
}
