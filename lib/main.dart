import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
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

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        CrashReporter.instance
            .report(details.exception, details.stack ?? StackTrace.empty);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        CrashReporter.instance.report(error, stack);
        return true;
      };

      await CrashReporter.instance.init();

      await Hive.initFlutter();
      final settings = await Hive.openBox<String>('settings');
      final votes = await Hive.openBox<String>('votes');

      final favorites = await Hive.openBox<String>('favorites');
      final favoriteComments = await Hive.openBox<String>('favorites_comments');
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
            calendarBoxProvider.overrideWithValue(calendarCache),
          ],
          child: const SvalkoApp(),
        ),
      );

      _initDeepLinks();
    },
    (error, stack) => CrashReporter.instance.report(error, stack),
  );
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
  navigatorKey.currentState?.pushNamed('/post', arguments: postId);
}
