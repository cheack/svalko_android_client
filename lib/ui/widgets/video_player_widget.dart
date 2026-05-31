import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/app_logger.dart';
import '../../core/settings_storage.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({super.key, required this.url});

  final String url;

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _vpc;
  ChewieController? _chewie;
  Uint8List? _thumbnail;
  double? _thumbAspectRatio;
  int? _remoteSize;
  bool _error = false;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(autoLoadVideoProvider)) {
      _initPlayer(autoPlay: false);
    } else {
      _loadThumbnail();
      _fetchSize();
    }
  }

  Future<void> _fetchSize() async {
    try {
      final response = await http.head(Uri.parse(widget.url));
      final cl = response.headers['content-length'];
      if (mounted && cl != null) setState(() => _remoteSize = int.tryParse(cl));
    } catch (_) {}
  }

  String _ext() {
    final ext = widget.url.split('.').last.split('?').first.toUpperCase();
    return ext.length <= 4 ? ext : 'ВИДЕО';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<File> _thumbCacheFile() async {
    final tmp = await getTemporaryDirectory();
    // base64url avoids hash collisions and is safe as a filename
    final key = base64Url.encode(utf8.encode(widget.url)).replaceAll('=', '');
    return File('${tmp.path}/video_thumbs/$key.jpg');
  }

  Future<void> _loadThumbnail() async {
    try {
      final file = await _thumbCacheFile();
      if (file.existsSync() && file.lengthSync() > 0) {
        final bytes = await file.readAsBytes();
        final ratio = await _decodeAspectRatio(bytes);
        if (mounted) setState(() { _thumbnail = bytes; _thumbAspectRatio = ratio; });
        AppLogger.instance.network('video thumb cached: ${file.path}');
        return;
      }
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 70,
      );
      if (bytes != null) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
      if (mounted) {
        final ratio = bytes != null ? await _decodeAspectRatio(bytes) : null;
        setState(() { _thumbnail = bytes; _thumbAspectRatio = ratio; });
      }
      AppLogger.instance.network(
        bytes != null ? 'video thumb ok: ${bytes.length}b' : 'video thumb null',
      );
    } catch (e) {
      AppLogger.instance.error('video thumb error', detail: e.toString());
    }
  }

  static Future<double?> _decodeAspectRatio(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      return h > 0 ? w / h : null;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _initPlayer({bool autoPlay = true}) async {
    setState(() => _tapped = true);
    final url = widget.url;
    final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? url;
    AppLogger.instance.network('video start: $name');
    final vpc = VideoPlayerController.networkUrl(Uri.parse(url));
    _vpc = vpc;
    final sw = Stopwatch()..start();
    try {
      await vpc.initialize();
      sw.stop();
      AppLogger.instance.network('video ready: ${sw.elapsedMilliseconds}ms $name');
      if (!mounted) return;
      setState(() {
        _chewie = ChewieController(
          videoPlayerController: vpc,
          aspectRatio: vpc.value.aspectRatio,
          autoPlay: autoPlay,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControlsOnInitialize: !autoPlay,
        );
      });
    } catch (e) {
      AppLogger.instance.error('video error: $name', detail: e.toString());
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_error) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        color: cs.surfaceContainerHigh,
        child: const Icon(Icons.videocam_off_outlined),
      );
    }

    if (_chewie != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Chewie(controller: _chewie!),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final ratio = _thumbAspectRatio ?? 16 / 9;
        final h = (w / ratio).clamp(0.0, 480.0);
        return SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            onTap: _tapped ? null : _initPlayer,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: _thumbnail != null
                      ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                      : ColoredBox(color: cs.surfaceContainerHigh),
                ),
                if (_tapped)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(
                          _thumbnail == null
                              ? 'Загрузка превью...'
                              : _remoteSize != null
                                  ? '${_ext()} · ${_formatBytes(_remoteSize!)}'
                                  : _ext(),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
