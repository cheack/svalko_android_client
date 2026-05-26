import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/settings_storage.dart';
import 'features/about/about_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/images/images_screen.dart';
import 'features/logs/logs_screen.dart';
import 'features/post/post_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/trends/trends_screen.dart';
import 'models/author.dart';
import 'models/feed_source.dart';
import 'models/tag.dart';
import 'ui/theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class SvalkoApp extends ConsumerWidget {
  const SvalkoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
          return MaterialPageRoute(builder: (_) => const FeedScreen());
        }
        if (settings.name == '/post' || settings.name == '/random-post') {
          final args = settings.arguments;
          final int postId;
          final int? commentId;
          if (args is (int, int?)) {
            postId = args.$1;
            commentId = args.$2;
          } else {
            postId = args as int;
            commentId = null;
          }
          return MaterialPageRoute(
            builder: (_) => PostScreen(
              postId: postId,
              highlightCommentId: commentId,
              showShuffle: settings.name == '/random-post',
            ),
          );
        }
        if (settings.name == '/tag') {
          final tag = settings.arguments as Tag;
          return MaterialPageRoute(
            builder: (_) => FeedScreen(
              source: TagFeed(tagId: tag.id, tagName: tag.name),
            ),
          );
        }
        if (settings.name == '/author') {
          final author = settings.arguments as Author;
          return MaterialPageRoute(
            builder: (_) => FeedScreen(
              source: AuthorFeed(
                authorName: author.name,
                profileUrl: author.profileUrl,
              ),
            ),
          );
        }
        if (settings.name == '/images') {
          return MaterialPageRoute(builder: (_) => const ImagesScreen());
        }
        if (settings.name == '/settings') {
          return MaterialPageRoute(builder: (_) => const SettingsScreen());
        }
        if (settings.name == '/logs') {
          return MaterialPageRoute(builder: (_) => const LogsScreen());
        }
        if (settings.name == '/about') {
          return MaterialPageRoute(builder: (_) => const AboutScreen());
        }
        if (settings.name == '/favorites') {
          return MaterialPageRoute(builder: (_) => const FavoritesScreen());
        }
        if (settings.name == '/trends') {
          return MaterialPageRoute(builder: (_) => const TrendsScreen());
        }
        return null;
      },
    );
  }
}
