import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

const _browserChannel = MethodChannel('org.svalko/browser');

/// Opens [url] in an external browser.
///
/// For svalko.org URLs on Android we call a platform channel that explicitly
/// opens the default browser, bypassing App Links interception.
Future<void> openInBrowser(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  if (Platform.isAndroid && _isSvalkoUrl(uri)) {
    try {
      await _browserChannel.invokeMethod('openInDefaultBrowser', {'url': url});
      return;
    } on PlatformException {
      // Fall through to url_launcher
    }
  }

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}

/// Copies [url] to the clipboard and shows a confirmation snackbar.
Future<void> copyLinkToClipboard(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }
}

bool _isSvalkoUrl(Uri uri) =>
    uri.host == 'svalko.org' || uri.host == 'pda.svalko.org' ||
    uri.host == 'ta.svalko.org' || uri.host == 'pda.ta.svalko.org' ||
    uri.host == Uri.parse(Config.baseUrl).host;
