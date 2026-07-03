import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_storage.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../../ui/widgets/inline_spinner.dart';
import '../feed/feed_controller.dart' show navigateToRandomPost;
import 'dark_side_post_tile.dart';
import 'dark_side_random_post_controller.dart';

class DarkSideRandomPostScreen extends ConsumerStatefulWidget {
  const DarkSideRandomPostScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<DarkSideRandomPostScreen> createState() =>
      _DarkSideRandomPostScreenState();
}

class _DarkSideRandomPostScreenState
    extends ConsumerState<DarkSideRandomPostScreen> {
  bool _loadingRandom = false;

  Future<void> _shuffle() async {
    if (_loadingRandom) return;
    setState(() => _loadingRandom = true);
    await navigateToRandomPost(ref, context, (id) {
      Navigator.of(context)
          .pushReplacementNamed('/dark-side-post', arguments: id);
    });
    if (mounted) setState(() => _loadingRandom = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(darkSideRandomPostControllerProvider(widget.postId));
    final fontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тёмная сторона свалки'),
        actions: [
          IconButton(
            icon: _loadingRandom
                ? const InlineSpinner()
                : const Icon(Icons.shuffle_outlined),
            tooltip: 'Что попало',
            onPressed: _shuffle,
          ),
        ],
      ),
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontSize / FontSizeNotifier.defaultSize),
        ),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(DarkSideRandomPostState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null || state.post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error?.toString() ?? 'Ошибка разбора страницы'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(darkSideRandomPostControllerProvider(widget.postId).notifier)
                  .load(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    return SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: landscapeHPadding(context)),
        child: DarkSidePostTile(post: state.post!),
      ),
    );
  }
}
