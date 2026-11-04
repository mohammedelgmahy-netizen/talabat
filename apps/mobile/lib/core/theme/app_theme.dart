import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFFFF5A00);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary)
        .copyWith(onSurface: Colors.black, onSurfaceVariant: const Color(0xFF1F2937));
    // خط أكبر وأغمق: كل الكلام أسود وتقيل شوية
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Roboto').textTheme;
    TextStyle? bold(TextStyle? t) => t?.copyWith(
          fontWeight: const [FontWeight.w700, FontWeight.w800, FontWeight.w900].contains(t.fontWeight) ? t.fontWeight : FontWeight.w600,
        );
    final text = base.apply(fontSizeFactor: 1.15, bodyColor: Colors.black, displayColor: Colors.black);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      textTheme: text.copyWith(
        displayLarge: bold(text.displayLarge),
        displayMedium: bold(text.displayMedium),
        displaySmall: bold(text.displaySmall),
        headlineLarge: bold(text.headlineLarge),
        headlineMedium: bold(text.headlineMedium),
        headlineSmall: bold(text.headlineSmall),
        titleLarge: bold(text.titleLarge),
        titleMedium: bold(text.titleMedium),
        titleSmall: bold(text.titleSmall),
        bodyLarge: bold(text.bodyLarge),
        bodyMedium: bold(text.bodyMedium),
        bodySmall: bold(text.bodySmall),
        labelLarge: bold(text.labelLarge),
        labelMedium: bold(text.labelMedium),
        labelSmall: bold(text.labelSmall),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
