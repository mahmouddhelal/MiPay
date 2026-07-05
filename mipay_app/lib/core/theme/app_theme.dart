import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark()  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primary        = isDark ? AppColors.ink50  : AppColors.ink900;
    final onPrimary      = isDark ? AppColors.ink900 : AppColors.ink0;
    final surface        = isDark ? AppColors.ink950 : AppColors.ink0;
    final onSurface      = isDark ? AppColors.ink50  : AppColors.ink900;
    final surfaceVariant = isDark ? AppColors.ink800 : AppColors.ink100;
    final outline        = isDark ? AppColors.ink600 : AppColors.ink300;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? AppColors.ink800 : AppColors.ink100,
      onPrimaryContainer: isDark ? AppColors.ink100 : AppColors.ink800,
      secondary: isDark ? AppColors.ink400 : AppColors.ink500,
      onSecondary: isDark ? AppColors.ink950 : AppColors.ink0,
      secondaryContainer: isDark ? AppColors.ink700 : AppColors.ink200,
      onSecondaryContainer: isDark ? AppColors.ink100 : AppColors.ink800,
      error: isDark ? AppColors.expenseDark : AppColors.expenseLight,
      onError: isDark ? AppColors.ink950 : AppColors.ink0,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: isDark ? AppColors.ink400 : AppColors.ink500,
      outline: outline,
      outlineVariant: isDark ? AppColors.ink700 : AppColors.ink200,
      inverseSurface: isDark ? AppColors.ink100 : AppColors.ink900,
      onInverseSurface: isDark ? AppColors.ink900 : AppColors.ink0,
      inversePrimary: isDark ? AppColors.ink900 : AppColors.ink50,
      surfaceContainerHighest: isDark ? AppColors.ink700 : AppColors.ink100,
      surfaceContainerHigh: isDark ? AppColors.ink800 : AppColors.ink50,
      surfaceContainer: isDark ? AppColors.ink900 : AppColors.ink50,
    );

    final textTheme = const TextTheme().copyWith(
      displayLarge:  const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -1),
      displayMedium: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall:  const TextStyle(fontWeight: FontWeight.w700),
      headlineLarge: const TextStyle(fontWeight: FontWeight.w700),
      headlineMedium:const TextStyle(fontWeight: FontWeight.w600),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w600),
      titleLarge:    const TextStyle(fontWeight: FontWeight.w600),
      titleMedium:   const TextStyle(fontWeight: FontWeight.w500),
      labelLarge:    const TextStyle(fontWeight: FontWeight.w600),
      // Tabular figures for amounts
      bodyLarge:     const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      bodyMedium:    const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [
        isDark ? AppSemanticColors.dark : AppSemanticColors.light,
      ],

      // ── Component themes ────────────────────────────────────────────────

      // Cards: elevation 0, outline border, radius 16
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: outline),
        ),
        color: surface,
      ),

      // Input fields: filled style, radius 12
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(
            color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),

      // FilledButton: 52px height, primary fill
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),

      // OutlinedButton: same radius
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          side: BorderSide(color: outline),
        ),
      ),

      // NavigationBar: inverted indicator (primary-colored pill)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: onPrimary, size: 22);
          }
          return IconThemeData(
            color: isDark ? AppColors.ink400 : AppColors.ink500,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? primary : (isDark ? AppColors.ink400 : AppColors.ink500),
          );
        }),
      ),

      // AppBar: no scroll tint, no elevation
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),

      // SnackBar: floating, dark background for contrast
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.ink100 : AppColors.ink900,
        contentTextStyle: TextStyle(color: isDark ? AppColors.ink900 : AppColors.ink0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),

      // Chip: outlined style
      chipTheme: ChipThemeData(
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        selectedColor: primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),

      // SegmentedButton
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primary,
          selectedForegroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ),
      ),
    );
  }
}
