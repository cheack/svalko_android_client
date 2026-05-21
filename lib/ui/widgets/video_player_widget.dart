import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.url});

  final String url;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _vpc;
  ChewieController? _chewie;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _vpc.initialize();
      if (!mounted) return;
      setState(() {
        _chewie = ChewieController(
          videoPlayerController: _vpc,
          aspectRatio: _vpc.value.aspectRatio,
          autoPlay: false,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vpc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
