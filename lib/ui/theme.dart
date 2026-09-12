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

class AppColors {
  static const seed = Color(0xFF0F6B5C);
  static const cream = Color(0xFFF4F1EA);
  static const ink = Color(0xFF1C1F1E);
  static const income = Color(0xFF1B7F5A);
  static const expense = Color(0xFFC45D26);
  static const optional = Color(0xFFC9783A);
  static const net = Color(0xFFC9A227);
  static const track = Color(0xFFE7E1D6);
  static const grid = Color(0xFFE4DDD0);
}

class AppTheme {
  static const seed = AppColors.seed;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.seed,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD3EBE4),
      onPrimaryContainer: Color(0xFF07362F),
      secondary: Color(0xFFC9783A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF3E1D0),
      onSecondaryContainer: Color(0xFF4A2C12),
      tertiary: Color(0xFFC9A227),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: Color(0xFF5E675F),
      outline: Color(0xFFD6D0C6),
      outlineVariant: Color(0xFFE7E1D6),
      error: Color(0xFFB42318),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: AppColors.cream,
      visualDensity: VisualDensity.standard,
      textTheme: _textTheme(scheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        selectedColor: AppColors.seed.withValues(alpha: 0.14),
        backgroundColor: Colors.white,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.seed.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.seed.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: AppColors.seed),
        selectedLabelTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppColors.seed,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.seed, width: 1.4),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.seed,
        thumbColor: AppColors.seed,
        overlayColor: AppColors.seed.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.seed,
        linearTrackColor: AppColors.track,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(99),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displaySmall: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        height: 1.05,
        color: AppColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.35),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
