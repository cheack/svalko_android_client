import 'package:flutter/material.dart';
import '../core/skin.dart';
import 'skin_ext.dart';

// Blue skin colors
const _svalkoBlue = Color(0xFF364AA0);
const _svalkoBlueBg = Color(0xFFF6F6F7);
const _svalkoBlueCard = Color(0xFFECEEF8);
const _svalkoBlueInfoPanel = Color(0xFFD8DBEF);

// Yellow skin colors
const _svalkoYellow = Color(0xFFFFFF00);
const _svalkoYellowDark = Color(0xFF333333);
const _svalkoYellowBlue = Color(0xFF0000FF);
const _svalkoYellowBg = Color(0xFFFFFFFF);
const _svalkoYellowCard = Color(0xFFFFFFFF);
const _svalkoYellowInfoPanel = Color(0xFFFFFAC8);

// Pink skin colors
const _svalkoPink = Color(0xFFC245A1);
const _svalkoPinkBg = Color(0xFFFCF5FA);
const _svalkoPinkCard = Color(0xFFF9EEF6);
const _svalkoPinkInfoPanel = Color(0xFFF3DAEC);

// Dark side of svalko skin colors — taken from dark.side.of.svalko.org/css/darkside.css
const _darkSideBg = Color(0xFF000000);
const _darkSideCard = Color(0xFF0A0A0A);
const _darkSideText = Color(0xFF999999);
const _darkSideLink = Color(0xFF0084FF);
const _darkSideBorder = Color(0xFF222222);

const _heartPattern = DecorationImage(
  image: AssetImage('assets/heart-bg.png'),
  repeat: ImageRepeat.repeat,
  fit: BoxFit.none,
  alignment: Alignment.topLeft,
);

ThemeData themeForSkin(AppSkin skin) => switch (skin) {
      AppSkin.blue => _blueTheme,
      AppSkin.dark => _darkTheme,
      AppSkin.pink => _pinkTheme,
      AppSkin.yellow => _yellowTheme,
      AppSkin.darkSideSite => _darkSideSiteTheme,
    };

ThemeData _buildLightTheme({
  required Color primary,
  Color onPrimary = Colors.white,
  required Color bg,
  required Color card,
  required Color infoPanel,
  Color? secondaryColor,    // overrides secondary (used by tags, drawer labels)
  Color? appBarColor,       // if set, AppBar uses this; otherwise primary
  Color? onAppBar,          // text/icons on AppBar; defaults to onPrimary
  Color? interactiveColor,  // checkbox/radio/switch fill; defaults to primary
  DecorationImage? cardPattern,
  Color? headerColor,
  Color? linkColor,
  bool cardDividers = false,
}) {
  final secondary = secondaryColor ?? primary;
  final appBar = appBarColor ?? primary;
  final appBarFg = onAppBar ?? onPrimary;
  final interactive = interactiveColor ?? primary;
  return ThemeData(
    useMaterial3: true,
    extensions: [SvalkoSkinExt(
      cardPattern: cardPattern,
      headerColor: headerColor,
      linkColor: linkColor,
      cardDividers: cardDividers,
    )],
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: bg,
      onSurface: Colors.black,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: infoPanel,
      outline: primary,
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: primary, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: appBar,
      foregroundColor: appBarFg,
      elevation: 2,
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: secondary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? interactive : null),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((_) => interactive),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? interactive : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? interactive.withAlpha(80) : null),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: appBar,
      foregroundColor: appBarFg,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: appBar,
        foregroundColor: appBarFg,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: infoPanel,
      side: BorderSide(color: primary, width: 1),
      labelStyle: const TextStyle(fontSize: 11, color: Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    dividerColor: primary.withAlpha(60),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Colors.black),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF444444)),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      labelSmall: TextStyle(fontSize: 10),
    ),
  );
}

final _blueTheme = _buildLightTheme(
  primary: _svalkoBlue,
  bg: _svalkoBlueBg,
  card: _svalkoBlueCard,
  infoPanel: _svalkoBlueInfoPanel,
);

final _pinkTheme = _buildLightTheme(
  primary: _svalkoPink,
  bg: _svalkoPinkBg,
  card: _svalkoPinkCard,
  infoPanel: _svalkoPinkInfoPanel,
  cardPattern: _heartPattern,
);

final _yellowTheme = _buildLightTheme(
  primary: _svalkoYellowDark,
  bg: _svalkoYellowBg,
  card: _svalkoYellowCard,
  infoPanel: _svalkoYellowInfoPanel,
  secondaryColor: _svalkoYellowBlue,
  appBarColor: _svalkoYellow,
  onAppBar: Colors.black,
  headerColor: _svalkoYellow,
  linkColor: _svalkoYellowBlue,
  cardDividers: true,
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _svalkoBlue,
    brightness: Brightness.dark,
  ),
);

final _darkSideSiteTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const [
    SvalkoSkinExt(linkColor: _darkSideLink, headerColor: _darkSideLink, cardDividers: true),
  ],
  colorScheme: const ColorScheme.dark(
    primary: _darkSideLink,
    onPrimary: Colors.white,
    secondary: _darkSideLink,
    onSecondary: Colors.white,
    surface: _darkSideBg,
    onSurface: _darkSideText,
    surfaceContainerLow: _darkSideBg,
    surfaceContainer: _darkSideCard,
    surfaceContainerHigh: _darkSideCard,
    outline: _darkSideLink,
  ),
  scaffoldBackgroundColor: _darkSideBg,
  cardTheme: const CardThemeData(
    color: _darkSideCard,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _darkSideBg,
    foregroundColor: _darkSideLink,
    elevation: 0,
  ),
  listTileTheme: const ListTileThemeData(
    selectedColor: _darkSideLink,
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((_) => _darkSideLink),
  ),
  dividerColor: _darkSideBorder,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: _darkSideText),
    bodySmall: TextStyle(fontSize: 11, color: _darkSideText),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _darkSideLink),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkSideLink),
    labelSmall: TextStyle(fontSize: 10, color: _darkSideText),
  ),
);
