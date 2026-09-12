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
  static const seed = Color(0xFF0B5C50);
  static const cream = Color(0xFFDCD4C6);
  static const ink = Color(0xFF121615);
  static const muted = Color(0xFF3A4340);
  static const income = Color(0xFF146C4B);
  static const expense = Color(0xFFB44A16);
  static const optional = Color(0xFFB45C1C);
  static const net = Color(0xFF8A6B10);
  static const track = Color(0xFFC9C0B0);
  static const grid = Color(0xFFB7AD9C);
  static const border = Color(0xFF8E867A);
}

class AppTheme {
  static const seed = AppColors.seed;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.seed,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB7D8CF),
      onPrimaryContainer: Color(0xFF04241F),
      secondary: Color(0xFFB45C1C),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8C8A8),
      onSecondaryContainer: Color(0xFF3A1C08),
      tertiary: Color(0xFF8A6B10),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.border,
      outlineVariant: Color(0xFFC3BAAB),
      error: Color(0xFF9B1C14),
      surfaceContainerHighest: Color(0xFFEFE7DA),
    );
    final selectedLabel = WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      return AppColors.ink;
    });
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: AppColors.cream,
      visualDensity: VisualDensity.standard,
      textTheme: _textTheme(scheme),
      dividerColor: AppColors.border.withValues(alpha: 0.7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFD5CCBE),
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: AppColors.border, width: 1.2),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        selectedColor: AppColors.seed,
        backgroundColor: Colors.white,
        disabledColor: const Color(0xFFE8E1D6),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.seed;
          return Colors.white;
        }),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: selectedLabel,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 64,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        indicatorColor: AppColors.seed,
        overlayColor: WidgetStatePropertyAll(
          AppColors.seed.withValues(alpha: 0.08),
        ),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.muted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.seed : AppColors.muted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.seed,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: AppColors.seed,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.seed, width: 1.8),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.seed,
        inactiveTrackColor: AppColors.track,
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
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
        minVerticalPadding: 8,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displaySmall: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.05,
        color: AppColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleSmall: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: AppColors.ink,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.3,
        color: AppColors.muted,
      ),
      labelLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}
