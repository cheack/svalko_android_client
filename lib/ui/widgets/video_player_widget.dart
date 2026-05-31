import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_logger.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.url});

  final String url;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _vpc;
  ChewieController? _chewie;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
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

    if (_chewie == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: Chewie(controller: _chewie!),
    );
  }
}
