import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'config.dart';

/// Decodes raw bytes from svalko.org (windows-1251) to a Dart String.
Future<String> decodeWin1251(Uint8List bytes) =>
    CharsetConverter.decode(Config.charset, bytes);

/// URL-encodes a Cyrillic string using windows-1251 byte encoding.
/// Standard [Uri.encodeQueryComponent] only handles UTF-8.
Future<String> encodeQueryWin1251(String value) async {
  final bytes = await CharsetConverter.encode(Config.charset, value);
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write('%');
    buffer.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buffer.toString();
}
