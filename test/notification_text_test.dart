import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/features/notifications/notification_text.dart';

void main() {
  group('applyNotificationPlaceholders', () {
    test('replaces %username% with the given username', () {
      expect(
        applyNotificationPlaceholders('Комодер: смотри не перепутай %username%!',
            username: 'Вася'),
        'Комодер: смотри не перепутай Вася!',
      );
    });

    test('replaces every occurrence', () {
      expect(
        applyNotificationPlaceholders('%username%, привет, %username%!',
            username: 'Вася'),
        'Вася, привет, Вася!',
      );
    });

    test('falls back to a placeholder name when username is empty', () {
      expect(
        applyNotificationPlaceholders('Привет, %username%!', username: ''),
        'Привет, ХЗ кто!',
      );
    });

    test('leaves text without the token untouched', () {
      const text = 'Новый пост в разделе';
      expect(applyNotificationPlaceholders(text, username: 'Вася'), text);
    });
  });
}
