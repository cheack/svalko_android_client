import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';

sealed class TrendsBlock {}

class TrendsTextBlock extends TrendsBlock {
  TrendsTextBlock(this.text);
  final String text;
}

class TrendsImagesBlock extends TrendsBlock {
  TrendsImagesBlock(this.urls);
  final List<String> urls;
}

List<TrendsBlock> parseTrends(String html) {
  final doc = html_parser.parse(html);
  final content = doc.getElementById('content');
  if (content == null) return [];

  final blocks = <TrendsBlock>[];

  // Intro text from first h1 or direct paragraph before the image divs
  final h1 = content.querySelector('h1');
  if (h1 != null) {
    final text = h1.text.trim();
    if (text.isNotEmpty) blocks.add(TrendsTextBlock(text));
  }

  for (final div in content.querySelectorAll('div')) {
    final images = div.querySelectorAll('img[src*="trends_images.php"]');
    final paragraphs = div.querySelectorAll('p');

    if (images.isNotEmpty) {
      final urls = images
          .map((img) {
            final src = img.attributes['src'] ?? '';
            return src.startsWith('http')
                ? src
                : '${Config.baseUrl}/$src';
          })
          .where((u) => u.isNotEmpty)
          .toList();
      blocks.add(TrendsImagesBlock(urls));
    }

    for (final p in paragraphs) {
      final text = p.text.trim();
      if (text.isNotEmpty) blocks.add(TrendsTextBlock(text));
    }
  }

  return blocks;
}
