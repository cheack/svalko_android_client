import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';

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
          return {
            'color': _hexColor(colorScheme.primary),
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
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return true;
        }
        // Relative URL
        if (!url.startsWith('javascript')) {
          launchUrl(
            Uri.parse('${Config.baseUrl}/$url'),
            mode: LaunchMode.externalApplication,
          );
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
