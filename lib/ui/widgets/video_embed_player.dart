import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoEmbedPlayer extends StatefulWidget {
  const VideoEmbedPlayer({super.key, required this.url});

  final String url;

  static String? _embedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('coub.com')) {
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'view') {
        return 'https://coub.com/embed/${segs[1]}?autostart=false';
      }
    }
    return null;
  }

  static bool isSupported(String url) => _embedUrl(url) != null;

  @override
  State<VideoEmbedPlayer> createState() => _VideoEmbedPlayerState();
}

class _VideoEmbedPlayerState extends State<VideoEmbedPlayer> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final embedUrl = VideoEmbedPlayer._embedUrl(widget.url)!;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadHtmlString(_buildHtml(embedUrl));
  }

  static String _buildHtml(String embedUrl) => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe
    src="$embedUrl"
    allow="autoplay; encrypted-media; gyroscope; picture-in-picture; fullscreen"
    allowfullscreen>
  </iframe>
</body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
