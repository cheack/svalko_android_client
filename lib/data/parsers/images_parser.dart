import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config.dart';
import '../../models/image_item.dart';

// Matches: image_view('svalko.org', 'FILENAME', ...)
final _imageViewRe = RegExp(r"image_view\('[^']*',\s*'([^']+)'");

abstract final class ImagesParser {
  static List<ImageItem> parse(String htmlContent) {
    final doc = html_parser.parse(htmlContent);
    final items = <ImageItem>[];

    for (final link in doc.querySelectorAll('a[href*="image_view"]')) {
      try {
        final item = _parseItem(link);
        if (item != null) items.add(item);
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  static ImageItem? _parseItem(Element imageLink) {
    final href = imageLink.attributes['href'] ?? '';
    final match = _imageViewRe.firstMatch(href);
    final filename = match?.group(1);
    if (filename == null || filename.isEmpty) return null;

    final fullUrl = '${Config.baseUrl}/data/$filename';

    final img = imageLink.querySelector('img');
    var thumbUrl = img?.attributes['src'] ?? '';
    if (thumbUrl.isEmpty) thumbUrl = fullUrl;
    if (!thumbUrl.startsWith('http')) thumbUrl = '${Config.baseUrl}$thumbUrl';

    // Look for the "find=" link in the same container (sibling or parent).
    final container = imageLink.parent;
    final findLink = container?.querySelector('a[href*="find="]') ??
        container?.parent?.querySelector('a[href*="find="]');
    final findHref = findLink?.attributes['href'] ?? '';
    final findFilename =
        Uri.tryParse(findHref)?.queryParameters['find'] ?? filename;

    return ImageItem(
      thumbUrl: thumbUrl,
      fullUrl: fullUrl,
      filename: findFilename,
    );
  }
}
