import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:http/http.dart' as http;
import '../../core/app_logger.dart';
import '../../core/settings_storage.dart';
import 'image_viewer.dart';
import 'media_actions.dart';
import 'media_load_badge.dart';
import 'shimmer_placeholder.dart';

class ImageCarousel extends StatefulWidget {
  const ImageCarousel({super.key, required this.urls, this.maxHeight = 320});

  final List<String> urls;
  final double maxHeight;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _current = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _image(String url, {required BoxFit fit, Alignment alignment = Alignment.topCenter, Widget? loadingWidget}) =>
      MediaImage(url: url, fit: fit, alignment: alignment, loadingWidget: loadingWidget);

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final single = urls.length == 1;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (single)
          GestureDetector(
            onTap: () => showFullscreenCarousel(context, urls, 0),
            onLongPress: () => showMediaSheet(context, urls[0]),
            child: _image(
              urls[0],
              fit: BoxFit.fitWidth,
              loadingWidget: const SizedBox(
                height: 300,
                width: double.infinity,
                child: ShimmerPlaceholder(),
              ),
            ),
          )
        else
          ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: PageView.builder(
                  controller: _pageController,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, i) {
                    final url = urls[i];
                    return GestureDetector(
                      onTap: () => showFullscreenCarousel(context, urls, i),
                      onLongPress: () => showMediaSheet(context, url),
                      child: _image(url, fit: BoxFit.contain, alignment: Alignment.center),
                    );
                  },
                ),
        ),
        if (!single) ...[
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: _current > 0
                ? _NavArrow(
                    icon: Icons.chevron_left,
                    onTap: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: _current < urls.length - 1
                ? _NavArrow(
                    icon: Icons.chevron_right,
                    onTap: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(urls.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 8 : 5,
                  height: active ? 8 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class MediaImage extends ConsumerStatefulWidget {
  const MediaImage({
    super.key,
    required this.url,
    required this.fit,
    this.alignment = Alignment.topCenter,
    this.loadingWidget,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? loadingWidget;

  @override
  ConsumerState<MediaImage> createState() => MediaImageState();
}

// Keep at most this many decoded GIF frame-sets in memory at once.
const int _kMaxCachedGifs = 4;

class MediaImageState extends ConsumerState<MediaImage>
    with SingleTickerProviderStateMixin {
  bool _readyLogged = false;
  late final GifController? _gifController;
  File? _gifFile;
  double? _downloadProgress;
  StreamSubscription<FileResponse>? _downloadSub;
  // null = unknown, 0 = not cached, >0 = bytes
  int? _remoteSize;
  bool _manuallyTriggered = false;

  static String _name(String url) =>
      Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;

  bool get _isGif => isGifUrl(widget.url);

  /// Derives the server-generated static preview URL from the full GIF URL.
  static String? _gifPreviewUrl(String url) {
    const marker = '/data/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    return '${url.substring(0, idx)}/data/gif-previews/${url.substring(idx + marker.length)}';
  }

  @override
  void initState() {
    super.initState();
    if (_isGif) {
      _gifController = GifController(vsync: this);
      final autoLoad = ref.read(autoLoadMediaProvider);
      // Check if already cached on disk — always load from cache regardless of setting.
      DefaultCacheManager().getFileFromCache(widget.url).then((info) {
        if (!mounted) return;
        if (info != null) {
          _startDownload();
        } else if (autoLoad) {
          _startDownload();
        } else {
          _fetchRemoteSize();
        }
      });
    } else {
      _gifController = null;
    }
    AppLogger.instance.network('${_isGif ? 'gif' : 'img'} start: ${_name(widget.url)}');
  }

  void _startDownload() {
    if (_downloadSub != null) return;
    setState(() => _manuallyTriggered = true);
    _downloadSub = DefaultCacheManager()
        .getFileStream(widget.url, withProgress: true)
        .listen((event) {
      if (!mounted) return;
      if (event is DownloadProgress) {
        setState(() => _downloadProgress = event.progress);
      } else if (event is FileInfo) {
        setState(() => _gifFile = event.file);
      }
    });
  }

  Future<void> _fetchRemoteSize() async {
    try {
      final response = await http.head(Uri.parse(widget.url));
      final cl = response.headers['content-length'];
      if (mounted && cl != null) {
        setState(() => _remoteSize = int.tryParse(cl));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _gifController?.dispose();
    _evictGifCacheIfNeeded(widget.url);
    super.dispose();
  }

  static void _evictGifCacheIfNeeded(String url) {
    final cache = Gif.cache.caches;
    if (cache.length > _kMaxCachedGifs) {
      final toRemove = cache.keys
          .where((k) => k != url)
          .take(cache.length - _kMaxCachedGifs)
          .toList();
      for (final key in toRemove) {
        cache.remove(key);
      }
    }
  }

  Widget _gifBackground() {
    final preview = _gifPreviewUrl(widget.url);
    if (preview == null) return widget.loadingWidget ?? const ShimmerPlaceholder();
    return CachedNetworkImage(
      imageUrl: preview,
      width: double.infinity,
      fit: widget.fit,
      alignment: widget.alignment,
      placeholder: (_, _) => widget.loadingWidget ?? const ShimmerPlaceholder(),
      errorWidget: (_, _, _) => widget.loadingWidget ?? const ShimmerPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: Duration.zero,
    );
  }

  Widget _loadingPlaceholder(double? progress) => Stack(
    alignment: Alignment.center,
    children: [
      _gifBackground(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          progress != null ? '${(progress * 100).round()}%' : 'Загрузка...',
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
      ),
    ],
  );

  Widget _manualLoadPlaceholder() => GestureDetector(
    onTap: _startDownload,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _gifBackground(),
        MediaLoadBadge(
          label: _remoteSize != null ? 'GIF · ${formatMediaBytes(_remoteSize!)}' : 'GIF',
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final name = _name(url);

    if (url.toLowerCase().contains('.gif')) {
      if (_gifFile == null && !_manuallyTriggered) {
        return _manualLoadPlaceholder();
      }
      if (_gifFile == null) return _loadingPlaceholder(_downloadProgress);
      return Gif(
            image: FileImage(_gifFile!),
            controller: _gifController!,
            autostart: Autostart.no,
            width: double.infinity,
            fit: widget.fit,
            alignment: widget.alignment,
            placeholder: (_) => _loadingPlaceholder(null),
            onFetchCompleted: () {
              if (!_readyLogged) {
                _readyLogged = true;
                AppLogger.instance.network('gif ready: $name');
              }
              startGifIfValid(_gifController, () => mounted);
            },
          );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      fit: widget.fit,
      alignment: widget.alignment,
      placeholder: (_, _) => widget.loadingWidget ?? const ShimmerPlaceholder(),
      imageBuilder: (_, imageProvider) {
        if (!_readyLogged) {
          _readyLogged = true;
          AppLogger.instance.network('img ready: $name');
        }
        return Image(
          image: imageProvider,
          width: double.infinity,
          fit: widget.fit,
          alignment: widget.alignment,
        );
      },
      errorWidget: (_, _, error) {
        AppLogger.instance.error('img error: $name', detail: error.toString());
        return const SizedBox.shrink();
      },
      fadeOutDuration: Duration.zero,
      fadeInDuration: const Duration(milliseconds: 250),
    );
  }
}
