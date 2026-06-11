import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
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
    _FullscreenImageRoute(
      builder: (_) => _FullscreenCarouselPage(
        urls: urls,
        initialIndex: initialIndex,
        onOpenPost: onOpenPost,
      ),
    ),
  );
}

class _FullscreenImageRoute extends PageRoute<void> {
  _FullscreenImageRoute({required this.builder});

  static const double _backgroundScale = 1.035;

  final WidgetBuilder builder;
  final ValueNotifier<double> backgroundProgress = ValueNotifier<double>(1);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _backgroundTransition;

  @override
  void dispose() {
    backgroundProgress.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FullscreenImageRouteScope(
      progress: backgroundProgress,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  Widget? _backgroundTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (child == null) return null;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        secondaryAnimation,
        backgroundProgress,
      ]),
      child: child,
      builder: (_, child) {
        final progress = secondaryAnimation.value * backgroundProgress.value;
        final scale =
            1 + (_backgroundScale - 1) * Curves.easeOut.transform(progress);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class _FullscreenImageRouteScope extends InheritedWidget {
  const _FullscreenImageRouteScope({
    required this.progress,
    required super.child,
  });

  final ValueNotifier<double> progress;

  static ValueNotifier<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FullscreenImageRouteScope>()
        ?.progress;
  }

  @override
  bool updateShouldNotify(_FullscreenImageRouteScope oldWidget) {
    return progress != oldWidget.progress;
  }
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
    extends ConsumerState<_FullscreenCarouselPage>
    with SingleTickerProviderStateMixin {
  static const double _dismissThreshold = 120;
  static const double _axisLockDistance = 8;
  static const double _maxDismissibleScale = 1.01;
  static const double _minDragChromeOpacity = 0.18;

  late int _current;
  late final PageController _pageController;
  late final AnimationController _dragAnimationController;
  late final List<double> _imageScales;
  bool _postLoading = false;
  double _dragOffset = 0;
  int? _dragPointer;
  Offset? _dragStart;
  Axis? _dragAxis;
  ValueNotifier<double>? _backgroundProgress;

  double get _currentScale => _imageScales[_current];
  String get _currentUrl => widget.urls[_current];

  bool get _isDismissDragActive =>
      _dragAxis == Axis.vertical && _dragOffset != 0;
  double get _chromeOpacity {
    final progress = (_dragOffset.abs() / _dismissThreshold).clamp(0.0, 1.0);
    final opacity = 1 - Curves.easeOut.transform(progress);
    return opacity.clamp(_minDragChromeOpacity, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _dragAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _imageScales = List<double>.filled(widget.urls.length, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backgroundProgress = _FullscreenImageRouteScope.maybeOf(context);
    _syncBackgroundProgress();
  }

  @override
  void dispose() {
    _dragAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_dragPointer != null || _currentScale > _maxDismissibleScale) return;
    _dragAnimationController.stop();
    _dragPointer = event.pointer;
    _dragStart = event.position;
    _dragAxis = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer || _dragStart == null) return;
    if (_currentScale > _maxDismissibleScale) {
      _resetDrag();
      return;
    }

    final delta = event.position - _dragStart!;
    if (_dragAxis == null &&
        (delta.dx.abs() > _axisLockDistance ||
            delta.dy.abs() > _axisLockDistance)) {
      _dragAxis = delta.dy.abs() > delta.dx.abs()
          ? Axis.vertical
          : Axis.horizontal;
    }
    if (_dragAxis != Axis.vertical) return;

    _setDragOffset(delta.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointer) return;
    _finishDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _dragPointer) return;
    _animateDragOffset(0);
    _resetDrag(keepOffset: true);
  }

  void _finishDrag() {
    final shouldDismiss =
        _dragAxis == Axis.vertical && _dragOffset.abs() >= _dismissThreshold;
    final endOffset = shouldDismiss
        ? _dragOffset.sign * MediaQuery.sizeOf(context).height
        : 0.0;

    if (shouldDismiss) {
      _animateDragOffset(endOffset);
      Navigator.of(context).maybePop();
      _resetDrag(keepOffset: true);
      return;
    }

    _animateDragOffset(endOffset).whenComplete(() {
      if (!mounted) return;
      _resetDrag();
    });
  }

  Future<void> _animateDragOffset(double target) {
    final begin = _dragOffset;
    final animation = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(
        parent: _dragAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _dragAnimationController
      ..stop()
      ..reset();

    void listener() {
      if (mounted) _setDragOffset(animation.value);
    }

    animation.addListener(listener);
    return _dragAnimationController.forward().whenComplete(() {
      animation.removeListener(listener);
      if (mounted && target == 0) setState(() => _dragOffset = 0);
    });
  }

  void _resetDrag({bool keepOffset = false}) {
    _dragPointer = null;
    _dragStart = null;
    _dragAxis = null;
    if (!keepOffset && _dragOffset != 0) _setDragOffset(0);
  }

  void _setDragOffset(double value) {
    setState(() => _dragOffset = value);
    _syncBackgroundProgress();
  }

  void _syncBackgroundProgress() {
    final progress = _chromeOpacity;
    final notifier = _backgroundProgress;
    if (notifier == null || notifier.value == progress) return;
    notifier.value = progress;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(ref.watch(languageProvider));
    final multi = widget.urls.length > 1;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: _chromeOpacity),
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: IgnorePointer(
            ignoring: _isDismissDragActive,
            child: Opacity(
              opacity: _chromeOpacity,
              child: AppBar(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                elevation: 0,
                title: multi
                    ? Text(
                        '${_current + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
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
                            tooltip: s.postLink,
                            onPressed: () async {
                              setState(() => _postLoading = true);
                              await widget.onOpenPost!(_current);
                              if (mounted) {
                                setState(() => _postLoading = false);
                              }
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
            ),
          ),
        ),
        body: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) {
              _resetDrag();
              setState(() => _current = i);
            },
            itemBuilder: (_, i) => _FullscreenImageItem(
              url: widget.urls[i],
              onScaleChanged: (scale) => _imageScales[i] = scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageItem extends StatefulWidget {
  const _FullscreenImageItem({required this.url, required this.onScaleChanged});

  final String url;
  final ValueChanged<double> onScaleChanged;

  @override
  State<_FullscreenImageItem> createState() => _FullscreenImageItemState();
}

class _FullscreenImageItemState extends State<_FullscreenImageItem>
    with SingleTickerProviderStateMixin {
  late final GifController? _gifController;
  late final TransformationController _transformationController;
  Future<File>? _gifFile;

  bool get _isGif => widget.url.toLowerCase().contains('.gif');

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    if (_isGif) {
      _gifController = GifController(vsync: this);
      _gifFile = DefaultCacheManager().getSingleFile(widget.url);
    } else {
      _gifController = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _gifController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 8,
        onInteractionUpdate: (_) => widget.onScaleChanged(
          _transformationController.value.getMaxScaleOnAxis(),
        ),
        onInteractionEnd: (_) => widget.onScaleChanged(
          _transformationController.value.getMaxScaleOnAxis(),
        ),
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: _isGif
              ? FutureBuilder<File>(
                  future: _gifFile,
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      );
                    }
                    return Gif(
                      image: FileImage(snapshot.data!),
                      controller: _gifController!,
                      autostart: Autostart.loop,
                      fit: BoxFit.contain,
                      placeholder: (_) => const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    );
                  },
                )
              : CachedNetworkImage(
                  imageUrl: widget.url,
                  fit: BoxFit.contain,
                  progressIndicatorBuilder: (_, _, progress) => Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      value: progress.progress,
                    ),
                  ),
                  errorWidget: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
        ),
      ),
    );
  }
}
