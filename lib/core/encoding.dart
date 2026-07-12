import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'config.dart';

/// Decodes raw bytes from svalko.org (windows-1251) to a Dart String.
Future<String> decodeWin1251(Uint8List bytes) =>
    CharsetConverter.decode(Config.charset, bytes);

/// URL-encodes a Cyrillic string using windows-1251 byte encoding.
/// Standard [Uri.encodeQueryComponent] only handles UTF-8.
///
/// Characters windows-1251 can't represent (emoji, most other Unicode
/// symbols) are replaced with an HTML numeric character reference first —
/// the same fallback real browsers use when submitting a form whose page
/// charset doesn't cover a typed character. The forum renders comment text
/// as HTML, so `&#128512;` displays as the original emoji instead of the
/// native charset encoder silently mangling it into '?' or garbage bytes.
Future<String> encodeQueryWin1251(String value) async {
  final safe = await _replaceUnencodableChars(value);
  final bytes = await CharsetConverter.encode(Config.charset, safe);
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write('%');
    buffer.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buffer.toString();
}

// Per-rune cache: whether a code point round-trips through windows-1251
// unchanged. Avoids re-checking common emoji/symbols on every submission.
final Map<int, bool> _win1251EncodableCache = {};

Future<String> _replaceUnencodableChars(String value) async {
  final runes = value.runes.toList();
  for (final rune in runes.toSet()) {
    _win1251EncodableCache[rune] ??= await _isWin1251Encodable(rune);
  }
  final buffer = StringBuffer();
  for (final rune in runes) {
    if (_win1251EncodableCache[rune] == true) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write('&#$rune;');
    }
  }
  return buffer.toString();
}

Future<bool> _isWin1251Encodable(int rune) async {
  if (rune < 0x80) return true; // ASCII always maps 1:1.
  try {
    final char = String.fromCharCode(rune);
    final bytes = await CharsetConverter.encode(Config.charset, char);
    final roundTrip = await CharsetConverter.decode(Config.charset, bytes);
    return roundTrip == char;
  } catch (_) {
    return false;
  }
}
