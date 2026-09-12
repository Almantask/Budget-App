import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final eurFormat = NumberFormat.currency(locale: 'lt_LT', symbol: '€');

String formatEur(double value) => eurFormat.format(value);

String formatSignedEur(double value) {
  final abs = formatEur(value.abs());
  if (value > 0) return '+$abs';
  if (value < 0) return '-$abs';
  return abs;
}

String formatPct(double? value) {
  if (value == null) return '—';
  return '${(value * 100).toStringAsFixed(0)}%';
}

class AppTheme {
  static const seed = Color(0xFF0F6B5C);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F3EC),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF6F3EC),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: seed.withValues(alpha: 0.14),
      ),
    );
  }
}
