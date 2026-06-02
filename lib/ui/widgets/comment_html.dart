import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../core/config.dart';
import '../../core/open_url.dart';
import '../skin_ext.dart';

class CommentHtml extends StatelessWidget {
  const CommentHtml(this.html, {super.key, this.onSvalkoPost});

  final String html;
  final void Function(int postId)? onSvalkoPost;

  static final _svalkoPostRe = RegExp(
    r'https?://(?:www\.)?svalko\.org/(\d+)\.html',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return HtmlWidget(
      html,
      textStyle: theme.textTheme.bodyMedium,
      customStylesBuilder: (el) {
        if (el.localName == 'a') {
          final linkColor = theme.extension<SvalkoSkinExt>()?.linkColor;
          return {
            'color': _hexColor(linkColor ?? colorScheme.primary),
          };
        }
        if (el.localName == 'code') {
          return {
            'font-family': 'monospace',
            'background-color': _hexColor(
              colorScheme.surfaceContainerHigh,
            ),
          };
        }
        return null;
      },
      onTapUrl: (url) {
        final postId = int.tryParse(
          _svalkoPostRe.firstMatch(url)?.group(1) ?? '',
        );
        if (postId != null && onSvalkoPost != null) {
          onSvalkoPost!(postId);
          return true;
        }
        if (url.startsWith('http')) {
          openInBrowser(context, url);
          return true;
        }
        // Relative URL
        if (!url.startsWith('javascript')) {
          openInBrowser(context, '${Config.baseUrl}/$url');
          return true;
        }
        return false;
      },
    );
  }

  static String _hexColor(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return 'rgb($r,$g,$b)';
  }
}
