import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/settings_storage.dart';
import 'features/feed/feed_screen.dart';
import 'features/images/images_screen.dart';
import 'features/logs/logs_screen.dart';
import 'features/post/post_screen.dart';
import 'features/settings/settings_screen.dart';
import 'models/feed_source.dart';
import 'models/tag.dart';
import 'ui/theme.dart';

class SvalkoApp extends ConsumerWidget {
  const SvalkoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);

    return MaterialApp(
      title: 'Свалко',
      theme: themeForSkin(skin),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const FeedScreen());
        }
        if (settings.name == '/post') {
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
            builder: (_) => PostScreen(postId: postId, highlightCommentId: commentId),
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
        if (settings.name == '/images') {
          return MaterialPageRoute(builder: (_) => const ImagesScreen());
        }
        if (settings.name == '/settings') {
          return MaterialPageRoute(builder: (_) => const SettingsScreen());
        }
        if (settings.name == '/logs') {
          return MaterialPageRoute(builder: (_) => const LogsScreen());
        }
        return null;
      },
    );
  }
}
