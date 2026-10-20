import 'package:flutter/material.dart';

class RadiantColors {
  static const background = Color(0xFF0B0B0C);
  static const surface = Color(0xFF17171A);
  static const surfaceBorder = Color(0xFF2C2C30);
  static const maroon = Color(0xFF4A0E1F);
  static const maroonBright = Color(0xFF8A1C3A);
  static const yellow = Color(0xFFFFC400);
  static const amber = Color(0xFFF5A623);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const textMuted = Color(0xFF9A9AA0);
  static const disabled = Color(0xFF3A3A3E);
}

ThemeData buildRadiantTheme({bool highContrast = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: RadiantColors.maroon,
    brightness: Brightness.dark,
  ).copyWith(
    surface: RadiantColors.surface,
    primary: RadiantColors.yellow,
    error: RadiantColors.red,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        highContrast ? Colors.black : RadiantColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: RadiantColors.maroon,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: highContrast ? Colors.black : const Color(0xFF111113),
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? RadiantColors.yellow
              : RadiantColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? RadiantColors.yellow
              : RadiantColors.textMuted,
        ),
      ),
    ),
  );
}
