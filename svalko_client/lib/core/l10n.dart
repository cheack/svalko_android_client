import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { svalko, ru }

final languageProvider = StateProvider<AppLanguage>((_) => AppLanguage.svalko);

abstract class AppStrings {
  const AppStrings();

  String get appTitle;
  String get retry;
  String get refresh;
  String get openInBrowser;
  String get rating;
  String get unknownError;
  String get savePhoto;
  String get saveVideo;
  String get share;
  String get shareLink;
  String get photoSaved;
  String get videoSaved;
  String get navHome;
  String get navTags;

  /// "насрано 5 раз" / "5 комментариев" — used in post screen header
  String commentsHeader(int n);

  /// Short count label for post card (just the number, tooltip differs)
  String commentsTooltip(int n);

  static AppStrings of(AppLanguage lang) => switch (lang) {
        AppLanguage.svalko => const SvalkoStrings(),
        AppLanguage.ru => const RuStrings(),
      };
}

// ---------------------------------------------------------------------------
// Svalko (original site language)
// ---------------------------------------------------------------------------

class SvalkoStrings extends AppStrings {
  const SvalkoStrings();

  @override
  String get appTitle => 'Свалко!';

  @override
  String get retry => 'попробовать ещё';

  @override
  String get refresh => 'обновить';

  @override
  String get openInBrowser => 'открыть в браузере';

  @override
  String get rating => 'рейтинг';

  @override
  String get unknownError => 'чёт сломалось';

  @override
  String get savePhoto => 'сохранить фото';

  @override
  String get saveVideo => 'скачать видео';

  @override
  String get share => 'поделиться';

  @override
  String get shareLink => 'поделиться ссылкой';

  @override
  String get photoSaved => 'фото сохранено';

  @override
  String get videoSaved => 'видео сохранено';

  @override
  String get navHome => 'Главная';

  @override
  String get navTags => 'ТАГИ — ПТААГИ';

  @override
  String commentsHeader(int n) => 'насрано $n ${_raz(n)}';

  @override
  String commentsTooltip(int n) => 'насрано $n ${_raz(n)}';

  // 1 → "раз", 2-4 → "раза", 5+ → "раз"
  static String _raz(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 19) return 'раз';
    if (mod10 == 1) return 'раз';
    if (mod10 >= 2 && mod10 <= 4) return 'раза';
    return 'раз';
  }
}

// ---------------------------------------------------------------------------
// Standard Russian
// ---------------------------------------------------------------------------

class RuStrings extends AppStrings {
  const RuStrings();

  @override
  String get appTitle => 'Свалко';

  @override
  String get retry => 'Повторить';

  @override
  String get refresh => 'Обновить';

  @override
  String get openInBrowser => 'Открыть в браузере';

  @override
  String get rating => 'Рейтинг';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get savePhoto => 'Сохранить фото';

  @override
  String get saveVideo => 'Скачать видео';

  @override
  String get share => 'Поделиться';

  @override
  String get shareLink => 'Поделиться ссылкой';

  @override
  String get photoSaved => 'Фото сохранено';

  @override
  String get videoSaved => 'Видео сохранено';

  @override
  String get navHome => 'Главная';

  @override
  String get navTags => 'Теги';

  @override
  String commentsHeader(int n) => '$n ${_komentariy(n)}';

  @override
  String commentsTooltip(int n) => '$n ${_komentariy(n)}';

  // 1 → "комментарий", 2-4 → "комментария", 5+ → "комментариев"
  static String _komentariy(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 19) return 'комментариев';
    if (mod10 == 1) return 'комментарий';
    if (mod10 >= 2 && mod10 <= 4) return 'комментария';
    return 'комментариев';
  }
}
