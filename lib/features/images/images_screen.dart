import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/result.dart';
import '../../core/settings_storage.dart';
import '../../features/feed/feed_controller.dart';
import '../../models/image_item.dart';
import '../../ui/widgets/image_viewer.dart';
import '../../ui/widgets/blur_app_bar.dart';
import '../navigation/app_drawer.dart';
import 'images_controller.dart';

class ImagesScreen extends ConsumerStatefulWidget {
  const ImagesScreen({super.key});

  @override
  ConsumerState<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends ConsumerState<ImagesScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _tapImage(List<ImageItem> items, int index) {
    showFullscreenCarousel(
      context,
      items.map((e) => e.fullUrl).toList(),
      index,
      onOpenPost: (i) async {
        final result = await ref
            .read(repositoryProvider)
            .getImagePostId(items[i].filename);
        if (!mounted) return;
        switch (result) {
          case Ok(:final value):
            Navigator.of(context).pushNamed('/post', arguments: value);
          case Err(:final error):
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      },
    );
  }

  Future<void> _loadMore() async {
    await ref.read(imagesControllerProvider.notifier).load();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imagesControllerProvider);
    final s = AppStrings.of(ref.watch(languageProvider));

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(activePage: 'images'),
      drawerEdgeDragWidth: 80,
      appBar: buildBlurAppBar(context, title: Text(s.navImages)),
      body: _buildBody(state, s),
    );
  }

  Widget _buildBody(ImagesState state, AppStrings s) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error.toString()),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadMore,
              child: Text(s.retry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMore,
      child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            top: blurAppBarTopPadding(context),
            left: 4,
            right: 4,
            bottom: 4,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final item = state.items[i];
                return GestureDetector(
                  onTap: () => _tapImage(state.items, i),
                  child: CachedNetworkImage(
                    imageUrl: item.thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: Color(0x18808080)),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                );
              },
              childCount: state.items.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.isLoading
                  ? const CircularProgressIndicator()
                  : TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.refresh),
                      label: Text(s.more),
                    ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
