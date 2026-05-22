import 'package:html/dom.dart';

/// Extracts plain text from an HTML element, but replaces truncated link text
/// with the full href URL so that [LinkedText] can make them tappable correctly.
String extractText(Element el) {
  final buffer = StringBuffer();
  _visitNode(el, buffer);
  return buffer.toString().trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

void _visitNode(Node node, StringBuffer buf) {
  if (node.nodeType == Node.TEXT_NODE) {
    buf.write(node.text ?? '');
    return;
  }
  if (node.nodeType != Node.ELEMENT_NODE) return;

  final el = node as Element;
  final tag = el.localName?.toLowerCase() ?? '';

  if (tag == 'br') {
    buf.write('\n');
    return;
  }

  if (tag == 'em' || tag == 'i') {
    buf.write('<em>');
    for (final child in el.nodes) {
      _visitNode(child, buf);
    }
    buf.write('</em>');
    return;
  }

  if (tag == 'del' || tag == 's') {
    buf.write('<del>');
    for (final child in el.nodes) {
      _visitNode(child, buf);
    }
    buf.write('</del>');
    return;
  }

  // For <a href="..."> use the full href as text so truncated display text
  // (e.g. "https://...1.. ..rest.mp4") becomes the real URL.
  if (tag == 'a') {
    final href = el.attributes['href'] ?? '';
    if (href.startsWith('http')) {
      buf.write(href);
      return;
    }
    // Non-http links (e.g. anchor, javascript) — use visible text
    for (final child in el.nodes) {
      _visitNode(child, buf);
    }
    return;
  }

  for (final child in el.nodes) {
    _visitNode(child, buf);
  }
}
