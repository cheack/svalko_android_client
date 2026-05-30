import 'package:html/parser.dart' as html_parser;
import '../../models/ban_page_data.dart';

abstract final class BanPageParser {
  static bool isBanPage(String html) {
    final doc = html_parser.parse(html);
    if (doc.querySelectorAll('div.posting').isNotEmpty) return false;
    return (doc.body?.text.toLowerCase() ?? '').contains('забан');
  }

  static BanPageData parse(String html) {
    final doc = html_parser.parse(html);

    final form = doc.querySelector('form');
    final riddleQuestion =
        form != null ? _textBeforeFirstBr(form.innerHtml) : '';
    final riddleId = int.tryParse(
          form?.querySelector('input[name="q"]')?.attributes['value'] ?? '',
        ) ??
        0;

    final bodyText = doc.body?.text ?? '';
    final ipMatch = RegExp(r'\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)')
        .firstMatch(bodyText);
    final ipAddress = ipMatch?.group(1) ?? '';

    return BanPageData(
      riddleQuestion: riddleQuestion,
      riddleId: riddleId,
      ipAddress: ipAddress,
    );
  }

  static String _textBeforeFirstBr(String innerHtml) {
    final beforeBr = innerHtml.split(RegExp(r'<[Bb][Rr]\s*/?>')).first;
    return html_parser.parse(beforeBr).body?.text.trim() ?? '';
  }
}
