import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlRegex = RegExp(
  r'https?://[^\s<>"\)]+',
  caseSensitive: false,
);

// Matches https://svalko.org/12345.html or http://svalko.org/12345.html
final _svalkoPostRegex = RegExp(
  r'https?://(?:www\.)?svalko\.org/(\d+)\.html',
  caseSensitive: false,
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

  /// Called when the user taps a svalko.org post link. Receives the post id.
  /// If null, falls back to opening in browser.
  final void Function(int postId)? onSvalkoPost;

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        style ?? DefaultTextStyle.of(context).style;
    final linkStyle = defaultStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final url = match.group(0)!;
      final svalkoMatch = _svalkoPostRegex.firstMatch(url);
      final postId = int.tryParse(svalkoMatch?.group(1) ?? '');

      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (postId != null && onSvalkoPost != null) {
              onSvalkoPost!(postId);
            } else {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
      ));

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: spans, style: defaultStyle),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
