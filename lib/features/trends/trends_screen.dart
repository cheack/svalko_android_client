import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/result.dart';
import '../../data/parsers/trends_parser.dart';
import '../../features/feed/feed_controller.dart';
import '../../ui/widgets/shimmer_placeholder.dart';

final _trendsProvider = FutureProvider<List<TrendsBlock>>((ref) async {
  final result = await ref.read(apiProvider).fetchTrendsPage();
  return switch (result) {
    Ok(:final value) => parseTrends(value),
    Err() => [],
  };
});

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_trendsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Свалканалитическая сводка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_trendsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Ошибка загрузки')),
        data: (blocks) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: blocks.length,
          itemBuilder: (context, i) {
            final block = blocks[i];
            return switch (block) {
              TrendsTextBlock(:final text) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(text, style: theme.textTheme.bodyMedium),
                ),
              TrendsImagesBlock(:final urls) => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: urls
                        .map((url) => CachedNetworkImage(
                              imageUrl: url,
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
                              placeholder: (_, _) => const SizedBox(
                                height: 200,
                                child: ShimmerPlaceholder(),
                              ),
                              errorWidget: (_, _, _) => const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 40),
                                ),
                              ),
                              fadeOutDuration: Duration.zero,
                              fadeInDuration:
                                  const Duration(milliseconds: 250),
                            ))
                        .toList(),
                  ),
                ),
            };
          },
        ),
      ),
    );
  }
}
