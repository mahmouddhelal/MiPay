import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ThemeExtension that carries semantic colors (income / expense / warning).
/// Access via `context.semantics` — no more `Colors.*` in UI code.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.chartPalette,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final List<Color> chartPalette;

  static const AppSemanticColors light = AppSemanticColors(
    income: AppColors.incomeLight,
    expense: AppColors.expenseLight,
    warning: AppColors.warningLight,
    warningContainer: AppColors.warningContainerLight,
    onWarningContainer: AppColors.warningLight,
    // 8-step grayscale ramp for chart slices
    chartPalette: [
      Color(0xFF18181C),
      Color(0xFF3C3C45),
      Color(0xFF55555F),
      Color(0xFF737382),
      Color(0xFFA0A0AC),
      Color(0xFFC8C8D0),
      Color(0xFFE3E3E8),
      Color(0xFFF2F2F4),
    ],
  );

  static const AppSemanticColors dark = AppSemanticColors(
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    warning: AppColors.warningDark,
    warningContainer: AppColors.warningContainerDark,
    onWarningContainer: AppColors.warningDark,
    chartPalette: [
      Color(0xFFF9F9FA),
      Color(0xFFE3E3E8),
      Color(0xFFC8C8D0),
      Color(0xFFA0A0AC),
      Color(0xFF737382),
      Color(0xFF55555F),
      Color(0xFF3C3C45),
      Color(0xFF28282F),
    ],
  );

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    List<Color>? chartPalette,
  }) =>
      AppSemanticColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
        chartPalette: chartPalette ?? this.chartPalette,
      );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      chartPalette: List.generate(
        chartPalette.length,
        (i) => Color.lerp(chartPalette[i], other.chartPalette[i], t)!,
      ),
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantics =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
