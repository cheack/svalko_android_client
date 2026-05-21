import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/repositories/svalko_repository.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/image_item.dart';

class ImagesState {
  const ImagesState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ImageItem> items;
  final bool isLoading;
  final AppError? error;

  ImagesState copyWith({
    List<ImageItem>? items,
    bool? isLoading,
    AppError? error,
    bool clearError = false,
  }) =>
      ImagesState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ImagesController extends StateNotifier<ImagesState> {
  ImagesController(this._repo) : super(const ImagesState()) {
    load();
  }

  final SvalkoRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getImages();
    state = switch (result) {
      Ok(:final value) => ImagesState(items: value),
      Err(:final error) => ImagesState(error: error),
    };
  }
}

final imagesControllerProvider =
    StateNotifierProvider.autoDispose<ImagesController, ImagesState>(
  (ref) => ImagesController(ref.watch(repositoryProvider)),
);
