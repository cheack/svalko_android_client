import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlRegex = RegExp(
  r'https?://[^\s<>"\)]+',
  caseSensitive: false,
);

final _svalkoPostRegex = RegExp(
  r'https?://(?:www\.)?svalko\.org/(\d+)\.html',
  caseSensitive: false,
);

// Matches <em>...</em> and <del>...</del>
final _inlineTagRegex = RegExp(
  r'<(em|del)>(.*?)</(em|del)>',
  caseSensitive: false,
  dotAll: true,
);

class LinkedText extends StatelessWidget {
  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.onSvalkoPost,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final void Function(int postId)? onSvalkoPost;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final linkStyle = defaultStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final m in _inlineTagRegex.allMatches(text)) {
      if (m.start > cursor) {
        _addUrlSpans(text.substring(cursor, m.start), defaultStyle, linkStyle, spans, onSvalkoPost);
      }
      final tag = m.group(1)!.toLowerCase();
      final inner = m.group(2)!;
      final tagStyle = switch (tag) {
        'em'  => defaultStyle.copyWith(fontStyle: FontStyle.italic),
        'del' => defaultStyle.copyWith(decoration: TextDecoration.lineThrough),
        _     => defaultStyle,
      };
      final tagLinkStyle = tagStyle.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: tag == 'del'
            ? TextDecoration.combine([TextDecoration.lineThrough, TextDecoration.underline])
            : TextDecoration.underline,
        decorationColor: Theme.of(context).colorScheme.primary,
      );
      _addUrlSpans(inner, tagStyle, tagLinkStyle, spans, onSvalkoPost);
      cursor = m.end;
    }

    if (cursor < text.length) {
      _addUrlSpans(text.substring(cursor), defaultStyle, linkStyle, spans, onSvalkoPost);
    }

    return Text.rich(
      TextSpan(children: spans, style: defaultStyle),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  static void _addUrlSpans(
    String text,
    TextStyle baseStyle,
    TextStyle linkStyle,
    List<InlineSpan> spans,
    void Function(int)? onSvalkoPost,
  ) {
    int cursor = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
      }
      final url = match.group(0)!;
      final postId = int.tryParse(_svalkoPostRegex.firstMatch(url)?.group(1) ?? '');
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (postId != null && onSvalkoPost != null) {
              onSvalkoPost(postId);
            } else {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
  }
}
