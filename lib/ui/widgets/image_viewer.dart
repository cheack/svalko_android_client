import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/settings_storage.dart';
import 'media_actions.dart';

void showFullscreenImage(BuildContext context, String url) {
  showFullscreenCarousel(context, [url], 0);
}

void showFullscreenCarousel(
  BuildContext context,
  List<String> urls,
  int initialIndex, {
  Future<void> Function(int index)? onOpenPost,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenCarouselPage(
        urls: urls,
        initialIndex: initialIndex,
        onOpenPost: onOpenPost,
      ),
    ),
  );
}

class _FullscreenCarouselPage extends ConsumerStatefulWidget {
  const _FullscreenCarouselPage({
    required this.urls,
    required this.initialIndex,
    this.onOpenPost,
  });

  final List<String> urls;
  final int initialIndex;
  final Future<void> Function(int index)? onOpenPost;

  @override
  ConsumerState<_FullscreenCarouselPage> createState() =>
      _FullscreenCarouselPageState();
}

class _FullscreenCarouselPageState
    extends ConsumerState<_FullscreenCarouselPage> {
  late int _current;
  late final PageController _pageController;
  bool _postLoading = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentUrl => widget.urls[_current];

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(ref.watch(languageProvider));
    final multi = widget.urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        title: multi
            ? Text(
                '${_current + 1} / ${widget.urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              )
            : null,
        actions: [
          if (widget.onOpenPost != null)
            _postLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.open_in_new_outlined),
                    tooltip: s.openInBrowser,
                    onPressed: () async {
                      setState(() => _postLoading = true);
                      await widget.onOpenPost!(_current);
                      if (mounted) setState(() => _postLoading = false);
                    },
                  ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: s.savePhoto,
            onPressed: () => saveMedia(context, _currentUrl),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: s.share,
            onPressed: () => shareMedia(context, _currentUrl),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.urls[i];
          return LayoutBuilder(
            builder: (_, constraints) => InteractiveViewer(
              minScale: 0.5,
              maxScale: 8,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    final total = progress.expectedTotalBytes;
                    final loaded = progress.cumulativeBytesLoaded;
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        value: total != null ? loaded / total : null,
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
