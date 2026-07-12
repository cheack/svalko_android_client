import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/encoding.dart';

// Mimics java.nio.charset.Charset.encode/decode's default behavior for a
// single-byte charset like windows-1251: ASCII round-trips unchanged,
// anything else is replaced with the '?' (0x3F) substitute byte on encode.
void _installFakeCharsetConverter() {
  const channel = MethodChannel('charset_converter');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'encode':
        // On Linux the plugin sends the data pre-UTF-8-encoded (plus a
        // trailing NUL for C-string compatibility) instead of a raw String.
        final raw = call.arguments['data'];
        final data = raw is String
            ? raw
            : utf8.decode(
                (raw as Uint8List).takeWhile((b) => b != 0).toList());
        return Uint8List.fromList(
          data.runes.map((r) => r < 0x80 ? r : 0x3F).toList(),
        );
      case 'decode':
        final bytes = (call.arguments['data'] as Uint8List)
            .takeWhile((b) => b != 0)
            .toList();
        return latin1.decode(bytes);
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_installFakeCharsetConverter);

  test('ASCII/Cyrillic-range text encodes without numeric entities', () async {
    final result = await encodeQueryWin1251('hello');
    expect(result, isNot(contains('&#')));
    expect(result, equals('%68%65%6C%6C%6F'));
  });

  test('emoji is replaced with a numeric character reference, not "?"',
      () async {
    final result = await encodeQueryWin1251('hi \u{1F600}');
    // "&#128512;" percent-encoded, byte-for-byte (all ASCII).
    final expectedEntity = '&#128512;'
        .runes
        .map((r) => '%${r.toRadixString(16).padLeft(2, '0').toUpperCase()}')
        .join();
    expect(result, contains(expectedEntity));
    // Must not silently degrade to a literal '?' substitute (%3F) instead.
    expect(result, isNot(contains('%3F%3F')));
  });

  test('mixed text keeps encodable chars and replaces only the emoji',
      () async {
    final result = await encodeQueryWin1251('ok\u{1F600}ok');
    expect(result, startsWith('%6F%6B'));
    expect(result, endsWith('%6F%6B'));
    expect(result, contains('&#128512;'.runes.first.toString()));
  });
}
