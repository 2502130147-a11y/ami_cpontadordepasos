import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildAmatistaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.purple,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.purple,
    onPrimary: Colors.white,
    secondary: Palette.orchid,
    onSecondary: Colors.white,
    primaryContainer: Palette.lilacSoft,
    onPrimaryContainer: Palette.plum,
    surface: Palette.mist,
    onSurface: Palette.ink,
    error: Palette.danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'MPlusRounded');
  final radius18 = BorderRadius.circular(18);

  return base.copyWith(
    scaffoldBackgroundColor: Palette.mist,
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Palette.ink,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIconColor: Palette.violet,
      labelStyle: const TextStyle(color: Palette.inkMuted),
      border: OutlineInputBorder(borderRadius: radius18, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius18,
        borderSide: const BorderSide(color: Palette.lilacLine, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius18,
        borderSide: const BorderSide(color: Palette.purple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius18,
        borderSide: const BorderSide(color: Palette.danger, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius18,
        borderSide: const BorderSide(color: Palette.danger, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.plum,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Palette.lilacLine,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.purple,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.purple,
        side: const BorderSide(color: Palette.lilac, width: 1.4),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: Palette.purple,
      side: const BorderSide(color: Palette.lilacLine),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: Palette.purple,
      inactiveTrackColor: Palette.lilacSoft,
      thumbColor: Palette.purple,
      overlayColor: Palette.lilac.withValues(alpha: 0.25),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.purple),
  );
}
