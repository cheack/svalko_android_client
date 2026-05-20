import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'data/svalko_api.dart';
import 'features/feed/feed_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cacheDir = await getApplicationCacheDirectory();
  final cacheStore = FileCacheStore('${cacheDir.path}/http_cache');
  runApp(
    ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(SvalkoApi(cacheStore: cacheStore)),
      ],
      child: const SvalkoApp(),
    ),
  );
}
