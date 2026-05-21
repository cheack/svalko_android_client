import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/image_item.dart';

abstract final class ImagesParser {
  static List<ImageItem> parse(String htmlContent) {
    final doc = html_parser.parse(htmlContent);
    final items = <ImageItem>[];

    // Each gallery entry has an <a href="...?find=FILENAME"> link near an <img>.
    for (final link in doc.querySelectorAll('a[href*="find="]')) {
      try {
        final href = link.attributes['href'] ?? '';
        final uri = Uri.tryParse(href);
        final filename = uri?.queryParameters['find'] ?? '';
        if (filename.isEmpty) continue;

        // Look for img in the same container, then one level up.
        final container = link.parent;
        final img = container?.querySelector('img') ??
            container?.parent?.querySelector('img');
        if (img == null) continue;

        var src = img.attributes['src'] ?? '';
        if (src.isEmpty) continue;
        if (!src.startsWith('http')) src = '${Config.baseUrl}$src';

        items.add(ImageItem(imageUrl: src, filename: filename));
      } catch (_) {
        continue;
      }
    }
    return items;
  }
}
