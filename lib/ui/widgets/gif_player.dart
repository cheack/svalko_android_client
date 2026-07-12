// Vendored, minimal fork of the `gif` package (pub.dev, MIT), trimmed to the
// subset this app uses (FileImage/NetworkImage sources).
//
// Fixes a frame-index bug in the upstream package: it computes
// `frameIndex = ((frameCount - 1) * value).floor()`, which only reaches the
// last frame at the very instant `value == 1.0` — for low frame-count gifs
// (e.g. 2 frames) that last frame is shown for ~0 real time before the
// controller wraps back to 0, so the animation looks static. This fork uses
// `frameIndex = (frameCount * value).floor().clamp(0, frameCount - 1)`,
// giving every frame an equal, non-zero share of the playback duration.

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

final http.Client _sharedHttpClient = http.Client();

enum Autostart { no, once, loop }

@immutable
class Gif extends StatefulWidget {
  static GifCache cache = GifCache();

  final ImageProvider image;
  final GifController? controller;
  final int? fps;
  final Duration? duration;
  final Autostart autostart;
  final Widget Function(BuildContext context)? placeholder;
  final VoidCallback? onFetchCompleted;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool useCache;

  Gif({
    super.key,
    required this.image,
    this.controller,
    this.fps,
    this.duration,
    this.autostart = Autostart.no,
    this.placeholder,
    this.onFetchCompleted,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.useCache = true,
  })  : assert(fps == null || duration == null,
            'only one of the two can be set [fps] [duration]'),
        assert(fps == null || fps > 0, 'fps must be greater than 0');

  @override
  State<Gif> createState() => _GifState();
}

@immutable
class GifCache {
  final Map<String, GifInfo> caches = {};

  void clear() => caches.clear();

  bool evict(Object key) => caches.remove(key) != null;
}

class GifController extends AnimationController {
  @protected
  Duration? duration;

  GifController({required super.vsync});
}

@immutable
class GifInfo {
  final List<ImageInfo> frames;
  final Duration duration;

  GifInfo({required this.frames, required this.duration});
}

class _GifState extends State<Gif> with SingleTickerProviderStateMixin {
  late final GifController _controller;
  List<ImageInfo> _frames = [];
  int _frameIndex = 0;

  ImageInfo? get _frame =>
      _frames.length > _frameIndex ? _frames[_frameIndex] : null;

  @override
  Widget build(BuildContext context) {
    final RawImage image = RawImage(
      image: _frame?.image,
      width: widget.width,
      height: widget.height,
      scale: _frame?.scale ?? 1.0,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      matchTextDirection: widget.matchTextDirection,
    );
    return widget.placeholder != null && _frame == null
        ? widget.placeholder!(context)
        : widget.excludeFromSemantics
            ? image
            : Semantics(
                container: widget.semanticLabel != null,
                image: true,
                label: widget.semanticLabel ?? '',
                child: image,
              );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFrames().then((value) => _autostart());
  }

  @override
  void didUpdateWidget(Gif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_listener);
      _controller = widget.controller ?? GifController(vsync: this);
      _controller.addListener(_listener);
    }
    if ((widget.image != oldWidget.image) ||
        (widget.fps != oldWidget.fps) ||
        (widget.duration != oldWidget.duration)) {
      _loadFrames().then((value) {
        if (widget.image != oldWidget.image) _autostart();
      });
    }
    if (widget.autostart != oldWidget.autostart) _autostart();
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? GifController(vsync: this);
    _controller.addListener(_listener);
  }

  void _autostart() {
    if (mounted && widget.autostart != Autostart.no) {
      _controller.reset();
      if (widget.autostart == Autostart.loop) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    }
  }

  String _getImageKey(ImageProvider provider) => provider is NetworkImage
      ? provider.url
      : provider is AssetImage
          ? provider.assetName
          : provider is FileImage
              ? provider.file.path
              : provider is MemoryImage
                  ? provider.bytes.toString()
                  : '';

  void _listener() {
    if (_frames.isEmpty || !mounted) return;
    setState(() {
      _frameIndex =
          (_frames.length * _controller.value).floor().clamp(0, _frames.length - 1);
    });
  }

  Future<void> _loadFrames() async {
    if (!mounted) return;

    final GifInfo gif = widget.useCache &&
            Gif.cache.caches.containsKey(_getImageKey(widget.image))
        ? Gif.cache.caches[_getImageKey(widget.image)]!
        : await _fetchFrames(widget.image);

    if (!mounted) return;

    if (widget.useCache) {
      Gif.cache.caches.putIfAbsent(_getImageKey(widget.image), () => gif);
    }

    setState(() {
      _frames = gif.frames;
      _controller.duration = widget.fps != null
          ? Duration(
              milliseconds: (_frames.length / widget.fps! * 1000).round())
          : widget.duration ?? gif.duration;
      widget.onFetchCompleted?.call();
    });
  }

  static Future<GifInfo> _fetchFrames(ImageProvider provider) async {
    late final Uint8List bytes;

    if (provider is NetworkImage) {
      final resolved = Uri.base.resolve(provider.url);
      final response =
          await _sharedHttpClient.get(resolved, headers: provider.headers);
      bytes = response.bodyBytes;
    } else if (provider is AssetImage) {
      final key = await provider.obtainKey(const ImageConfiguration());
      bytes = (await key.bundle.load(key.name)).buffer.asUint8List();
    } else if (provider is FileImage) {
      bytes = await provider.file.readAsBytes();
    } else if (provider is MemoryImage) {
      bytes = provider.bytes;
    } else {
      throw ArgumentError.value(provider, 'provider', 'Unsupported ImageProvider');
    }

    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    final codec =
        await PaintingBinding.instance.instantiateImageCodecWithSize(buffer);
    final infos = <ImageInfo>[];
    var duration = Duration.zero;

    for (var i = 0; i < codec.frameCount; i++) {
      final frameInfo = await codec.getNextFrame();
      infos.add(ImageInfo(image: frameInfo.image));
      duration += frameInfo.duration;
    }

    return GifInfo(frames: infos, duration: duration);
  }
}
