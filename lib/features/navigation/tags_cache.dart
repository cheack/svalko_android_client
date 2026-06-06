import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/tag.dart';

class TagsCacheNotifier extends AsyncNotifier<List<Tag>> {
  static const _key = 'tags_cache';

  @override
  Future<List<Tag>> build() async {
    final box = ref.watch(settingsBoxProvider);
    final cached = box.get(_key);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        return list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return _fetch();
  }

  Future<List<Tag>> _fetch() async {
    final result = await ref.read(repositoryProvider).getTags();
    final tags = switch (result) {
      Ok(:final value) => value,
      Err() => <Tag>[],
    };
    if (tags.isNotEmpty) {
      final box = ref.read(settingsBoxProvider);
      box.put(_key, jsonEncode(tags.map((t) => t.toJson()).toList()));
    }
    return tags;
  }

  Future<void> clearAndRefetch() async {
    final box = ref.read(settingsBoxProvider);
    await box.delete(_key);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final tagsCacheProvider =
    AsyncNotifierProvider<TagsCacheNotifier, List<Tag>>(TagsCacheNotifier.new);
