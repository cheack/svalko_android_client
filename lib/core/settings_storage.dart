import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'l10n.dart';
import 'skin.dart';

/// Overridden in main.dart with the real opened Hive box.
final settingsBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

/// Stores votes: keys 'v_{postId}' and 'b_{postId}', values are int as string.
final votesBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

/// Stores calendar month data: key = month path (e.g. '/2025/10/1/'), value = JSON.
final calendarBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

// ---------------------------------------------------------------------------
// Skin
// ---------------------------------------------------------------------------

class SkinNotifier extends Notifier<AppSkin> {
  @override
  AppSkin build() {
    final box = ref.watch(settingsBoxProvider);
    final skin = AppSkin.values.firstWhere(
      (s) => s.name == box.get('skin'),
      orElse: () => AppSkin.blue,
    );
    listenSelf((_, next) => box.put('skin', next.name));
    return skin;
  }

  void set(AppSkin value) => state = value;
}

final skinProvider =
    NotifierProvider<SkinNotifier, AppSkin>(SkinNotifier.new);

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final box = ref.watch(settingsBoxProvider);
    final lang = AppLanguage.values.firstWhere(
      (l) => l.name == box.get('language'),
      orElse: () => AppLanguage.svalko,
    );
    listenSelf((_, next) => box.put('language', next.name));
    return lang;
  }

  void set(AppLanguage value) => state = value;
}

final languageProvider =
    NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

// ---------------------------------------------------------------------------
// Auto-load media (GIF)
// ---------------------------------------------------------------------------

class AutoLoadMediaNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(settingsBoxProvider);
    final v = box.get('autoLoadMedia');
    listenSelf((_, next) => box.put('autoLoadMedia', next.toString()));
    return v == null ? true : v == 'true';
  }

  void set(bool value) => state = value;
}

final autoLoadMediaProvider =
    NotifierProvider<AutoLoadMediaNotifier, bool>(AutoLoadMediaNotifier.new);

// ---------------------------------------------------------------------------
// Font size
// ---------------------------------------------------------------------------

class FontSizeNotifier extends Notifier<double> {
  static const _min = 11.0;
  static const _max = 20.0;
  static const defaultSize = 13.0;

  @override
  double build() {
    final box = ref.watch(settingsBoxProvider);
    final v = double.tryParse(box.get('fontSize') ?? '');
    listenSelf((_, next) => box.put('fontSize', next.toString()));
    return (v != null && v >= _min && v <= _max) ? v : defaultSize;
  }

  void set(double value) => state = value.clamp(_min, _max);
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);

// ---------------------------------------------------------------------------
// Auto-load video
// ---------------------------------------------------------------------------

class AutoLoadVideoNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(settingsBoxProvider);
    final v = box.get('autoLoadVideo');
    listenSelf((_, next) => box.put('autoLoadVideo', next.toString()));
    return v == null ? false : v == 'true';
  }

  void set(bool value) => state = value;
}

final autoLoadVideoProvider =
    NotifierProvider<AutoLoadVideoNotifier, bool>(AutoLoadVideoNotifier.new);
