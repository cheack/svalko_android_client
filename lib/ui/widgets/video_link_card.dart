import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoLinkCard extends StatelessWidget {
  const VideoLinkCard({super.key, required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  static String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.replaceFirst('www.', '');
    if (host == 'youtube.com') {
      final v = uri.queryParameters['v'];
      if (v != null) return v;
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'shorts') return segs[1];
    }
    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  static bool _isCoub(String url) =>
      Uri.tryParse(url)?.host.contains('coub.com') == true;

  static bool isSupported(String url) =>
      _youtubeId(url) != null || _isCoub(url);

  @override
  Widget build(BuildContext context) {
    final youtubeId = _youtubeId(url);
    final isCoub = _isCoub(url);
    if (youtubeId == null && !isCoub) return const SizedBox.shrink();

    final thumbUrl = youtubeId != null
        ? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'
        : null;
    final label = youtubeId != null ? 'YouTube' : 'Coub';

    return GestureDetector(
      onTap: onTap ?? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbUrl != null)
              Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _CoubPlaceholder(label: label),
              )
            else
              _CoubPlaceholder(label: label),
            // dark scrim
            const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black38),
            ),
            // play button
            const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white, size: 56),
            ),
            // label badge
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoubPlaceholder extends StatelessWidget {
  const _CoubPlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
