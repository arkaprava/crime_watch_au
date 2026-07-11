import 'package:flutter/material.dart';

/// Brand colours and shared theme configuration.
abstract final class AppTheme {
  static const Color navy = Color(0xFF1B2838);
  static const Color amber = Color(0xFFFCA311);
  static const Color slate = Color(0xFF415A77);
  static const Color mist = Color(0xFFE8EEF4);

  /// Backdrop blur strength for frosted glass panels.
  static const double glassBlurSigma = 16;

  static Color glassFill(Brightness brightness, {bool elevated = false}) {
    return switch (brightness) {
      Brightness.dark => elevated
          ? const Color(0xCC1B2838)
          : const Color(0xB31B2838),
      Brightness.light => elevated
          ? const Color(0xD9FFFFFF)
          : const Color(0xB8FFFFFF),
    };
  }

  static Color glassChipFill(Brightness brightness) {
    return switch (brightness) {
      Brightness.dark => const Color(0x99243447),
      Brightness.light => const Color(0x8CFFFFFF),
    };
  }

  static Color glassBorder(Brightness brightness) {
    return switch (brightness) {
      Brightness.dark => const Color(0x66E8EEF4),
      Brightness.light => const Color(0x99FFFFFF),
    };
  }

  static Color glassFabFill(Brightness brightness) {
    return switch (brightness) {
      Brightness.dark => const Color(0xE6FCA311),
      Brightness.light => const Color(0xE61B2838),
    };
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: amber,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: navy,
        titleTextStyle: const TextStyle(
          color: navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassChipFill(Brightness.light),
        hintStyle: TextStyle(color: slate.withValues(alpha: 0.7)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: slate.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: slate.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: slate.withValues(alpha: 0.28)),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        backgroundColor: glassChipFill(Brightness.light),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: glassFabFill(Brightness.light),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: glassBorder(Brightness.light)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: slate.withValues(alpha: 0.12),
        space: 1,
        thickness: 1,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: mist,
      secondary: amber,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F1419),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: glassChipFill(Brightness.dark),
        side: BorderSide(color: slate.withValues(alpha: 0.4)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: glassFabFill(Brightness.dark),
        foregroundColor: navy,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: glassBorder(Brightness.dark)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
