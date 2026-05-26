import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'image_viewer.dart';
import 'media_actions.dart';
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

  Widget _image(String url, {required BoxFit fit, Alignment alignment = Alignment.topCenter, Widget? loadingWidget}) {
    if (url.toLowerCase().contains('.gif')) {
      return Image.network(
        url,
        width: double.infinity,
        fit: fit,
        alignment: alignment,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : (loadingWidget ?? const ShimmerPlaceholder()),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      fit: fit,
      alignment: alignment,
      placeholder: (_, _) => loadingWidget ?? const ShimmerPlaceholder(),
      errorWidget: (_, _, _) => const SizedBox.shrink(),
      fadeOutDuration: Duration.zero,
      fadeInDuration: const Duration(milliseconds: 250),
    );
  }

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
