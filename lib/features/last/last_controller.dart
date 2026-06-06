import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/last_item.dart';

typedef LastData = (List<LastComment>, List<LastImage>);

const _pageSize = 10;

class LastNotifier extends AsyncNotifier<LastData> {
  int _skip = 0;

  int get skip => _skip;

  @override
  Future<LastData> build() => _fetch();

  Future<LastData> _fetch() async {
    final result = await ref.read(repositoryProvider).getLast(skip: _skip);
    return switch (result) {
      Ok(:final value) => value,
      Err(:final error) => throw error,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> resetToFirst() async {
    _skip = 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> loadNext() async {
    _skip += _pageSize;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> loadPrev() async {
    if (_skip == 0) return;
    _skip = (_skip - _pageSize).clamp(0, _skip);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final lastProvider =
    AsyncNotifierProvider<LastNotifier, LastData>(LastNotifier.new);
