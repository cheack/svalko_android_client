import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/parse_guard.dart';
import '../../core/result.dart';
import '../../data/parsers/dark_side_parser.dart';
import '../../data/svalko_api.dart';
import '../../models/dark_side_post.dart';
import '../feed/feed_controller.dart' show apiProvider;

class DarkSideRandomPostState {
  const DarkSideRandomPostState({this.post, this.isLoading = true, this.error});

  final DarkSidePost? post;
  final bool isLoading;
  final AppError? error;
}

class DarkSideRandomPostController extends StateNotifier<DarkSideRandomPostState> {
  DarkSideRandomPostController(this._api, this._id)
      : super(const DarkSideRandomPostState()) {
    load();
  }

  final SvalkoApi _api;
  final int _id;

  Future<void> load() async {
    state = const DarkSideRandomPostState(isLoading: true);
    final result = await _api.fetchPost(_id);
    switch (result) {
      case Err(:final error):
        state = DarkSideRandomPostState(error: error);
      case Ok(:final value):
        final parseResult = guardParse(() {
          final post = DarkSideParser.parseSinglePost(value, id: _id);
          if (post == null) {
            throw StateError('DarkSideParser: single post $_id did not match expected markup');
          }
          return post;
        });
        state = switch (parseResult) {
          Ok(:final value) => DarkSideRandomPostState(post: value, isLoading: false),
          Err() => const DarkSideRandomPostState(error: AppError.parseFailure),
        };
    }
  }
}

final darkSideRandomPostControllerProvider = StateNotifierProvider.family<
    DarkSideRandomPostController, DarkSideRandomPostState, int>(
  (ref, id) => DarkSideRandomPostController(ref.watch(apiProvider), id),
);
