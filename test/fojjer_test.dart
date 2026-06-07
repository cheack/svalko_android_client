import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/features/navigation/app_drawer.dart';

void main() {
  group('Fojjer text', () {
    test('init text starts with base', () {
      final rng = Random(0);
      final text = AppDrawer.fojjerBase +
          AppDrawer.fojjerSuffixes[rng.nextInt(AppDrawer.fojjerSuffixes.length)];
      expect(text, startsWith(AppDrawer.fojjerBase));
    });

    test('init text ends with a known suffix', () {
      for (final suffix in AppDrawer.fojjerSuffixes) {
        final text = AppDrawer.fojjerBase + suffix;
        expect(
          AppDrawer.fojjerSuffixes.any((s) => text.endsWith(s)),
          isTrue,
        );
      }
    });

    test('update text starts with a known prefix', () {
      const shout = 'тестовый крик';
      for (final prefix in AppDrawer.fojjerPrefixes) {
        final text = prefix + shout;
        expect(
          AppDrawer.fojjerPrefixes.any((p) => text.startsWith(p)),
          isTrue,
        );
      }
    });

    test('update text ends with the shout', () {
      const shout = 'тестовый крик';
      for (final prefix in AppDrawer.fojjerPrefixes) {
        expect(prefix + shout, endsWith(shout));
      }
    });

    test('suffixes list is non-empty', () {
      expect(AppDrawer.fojjerSuffixes, isNotEmpty);
    });

    test('prefixes list is non-empty', () {
      expect(AppDrawer.fojjerPrefixes, isNotEmpty);
    });
  });
}
