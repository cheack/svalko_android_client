import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/breadcrumb_collector.dart';
import 'core/settings_storage.dart';
import 'features/about/about_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/last/last_screen.dart';
import 'features/images/images_screen.dart';
import 'features/logs/logs_screen.dart';
import 'features/post/post_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/trends/trends_screen.dart';
import 'models/author.dart';
import 'models/feed_source.dart';
import 'models/search_result.dart';
import 'models/tag.dart';
import 'ui/theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class SvalkoApp extends ConsumerWidget {
  const SvalkoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    ref.watch(siteModeProvider); // initializes Config.baseUrl from saved setting

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [BreadcrumbCollector.instance.navigatorObserver],
      title: 'Свалко',
      theme: themeForSkin(skin),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru')],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(settings: settings,builder: (_) => const FeedScreen());
        }
        if (settings.name == '/post' || settings.name == '/random-post') {
          final args = settings.arguments;
          final int postId;
          final int? commentId;
          final int? initialPage;
          if (args is (int, int?, int?)) {
            postId = args.$1;
            commentId = args.$2;
            initialPage = args.$3;
          } else if (args is (int, int?)) {
            postId = args.$1;
            commentId = args.$2;
            initialPage = null;
          } else {
            postId = args as int;
            commentId = null;
            initialPage = null;
          }
          return MaterialPageRoute(settings: settings,
            builder: (_) => PostScreen(
              postId: postId,
              highlightCommentId: commentId,
              initialCommentPage: initialPage,
              showShuffle: settings.name == '/random-post',
            ),
          );
        }
        if (settings.name == '/tag') {
          final tag = settings.arguments as Tag;
          return MaterialPageRoute(settings: settings,
            builder: (_) => FeedScreen(
              source: TagFeed(tagId: tag.id, tagName: tag.name),
            ),
          );
        }
        if (settings.name == '/author') {
          final author = settings.arguments as Author;
          return MaterialPageRoute(settings: settings,
            builder: (_) => FeedScreen(
              source: AuthorFeed(
                authorName: author.name,
                profileUrl: author.profileUrl,
              ),
            ),
          );
        }
        if (settings.name == '/approver') {
          final feed = settings.arguments as ApproverFeed;
          return MaterialPageRoute(settings: settings,
            builder: (_) => FeedScreen(source: feed),
          );
        }
        if (settings.name == '/date') {
          final feed = settings.arguments as DateFeed;
          return MaterialPageRoute(settings: settings,
            builder: (_) => FeedScreen(source: feed),
          );
        }
        if (settings.name == '/last') {
          return MaterialPageRoute(settings: settings,builder: (_) => const LastScreen());
        }
        if (settings.name == '/images') {
          return MaterialPageRoute(settings: settings,builder: (_) => const ImagesScreen());
        }
        if (settings.name == '/settings') {
          return MaterialPageRoute(settings: settings,builder: (_) => const SettingsScreen());
        }
        if (settings.name == '/logs') {
          return MaterialPageRoute(settings: settings,builder: (_) => const LogsScreen());
        }
        if (settings.name == '/about') {
          return MaterialPageRoute(settings: settings,builder: (_) => const AboutScreen());
        }
        if (settings.name == '/favorites') {
          return MaterialPageRoute(settings: settings,builder: (_) => const FavoritesScreen());
        }
        if (settings.name == '/trends') {
          return MaterialPageRoute(settings: settings,builder: (_) => const TrendsScreen());
        }
        if (settings.name == '/search') {
          final params = settings.arguments as SearchParams;
          return MaterialPageRoute(settings: settings,
            builder: (_) => SearchScreen(params: params),
          );
        }
        return null;
      },
    );
  }
}
