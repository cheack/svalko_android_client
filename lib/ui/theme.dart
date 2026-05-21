import 'package:flutter/material.dart';
import '../core/skin.dart';

// Svalko site colors
const _svalkoBlue = Color(0xFF364AA0);
const _svalkoBg = Color(0xFFF6F6F7);
const _svalkoCard = Color(0xFFECEEF8);
const _svalkoInfoPanel = Color(0xFFD8DBEF);

ThemeData themeForSkin(AppSkin skin) => switch (skin) {
      AppSkin.blue => _blueTheme,
      AppSkin.dark => _darkTheme,
    };

final _blueTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: _svalkoBlue,
    onPrimary: Colors.white,
    secondary: _svalkoBlue,
    onSecondary: Colors.white,
    surface: _svalkoBg,
    onSurface: Colors.black,
    surfaceContainerLow: _svalkoCard,
    surfaceContainer: _svalkoCard,
    surfaceContainerHigh: _svalkoInfoPanel,
    outline: _svalkoBlue,
  ),
  cardTheme: const CardThemeData(
    color: _svalkoCard,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: _svalkoBlue, width: 1),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
  ),
  scaffoldBackgroundColor: _svalkoBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: _svalkoBlue,
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _svalkoInfoPanel,
    side: const BorderSide(color: _svalkoBlue, width: 1),
    labelStyle: const TextStyle(fontSize: 11, color: Colors.black),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  dividerColor: _svalkoBlue.withAlpha(60),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: Colors.black),
    bodySmall: TextStyle(fontSize: 11, color: Color(0xFF444444)),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    labelSmall: TextStyle(fontSize: 10),
  ),
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _svalkoBlue,
    brightness: Brightness.dark,
  ),
);
