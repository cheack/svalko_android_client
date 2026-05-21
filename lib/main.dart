import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'core/settings_storage.dart';
import 'data/svalko_api.dart';
import 'features/feed/feed_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final settings = await Hive.openBox<String>('settings');

  final cacheDir = await getApplicationCacheDirectory();
  final cacheStore = FileCacheStore('${cacheDir.path}/http_cache');

  runApp(
    ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(SvalkoApi(cacheStore: cacheStore)),
        settingsBoxProvider.overrideWithValue(settings),
      ],
      child: const SvalkoApp(),
    ),
  );
}
