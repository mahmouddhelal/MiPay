import 'package:flutter/material.dart';

/// Zinc-like neutral ink ramp — ink0 (white) → ink950 (near-black).
/// The accent is inversion: light mode primary = ink900, dark = ink50.
abstract final class AppColors {
  // ── Ink ramp ──────────────────────────────────────────────────────────────
  static const Color ink0   = Color(0xFFFFFFFF);
  static const Color ink50  = Color(0xFFF9F9FA);
  static const Color ink100 = Color(0xFFF2F2F4);
  static const Color ink200 = Color(0xFFE3E3E8);
  static const Color ink300 = Color(0xFFC8C8D0);
  static const Color ink400 = Color(0xFFA0A0AC);
  static const Color ink500 = Color(0xFF737382);
  static const Color ink600 = Color(0xFF55555F);
  static const Color ink700 = Color(0xFF3C3C45);
  static const Color ink800 = Color(0xFF28282F);
  static const Color ink900 = Color(0xFF18181C);
  static const Color ink950 = Color(0xFF0B0B0D);

  // ── Semantic hues — desaturated, readable in both themes ─────────────────
  static const Color incomeLight      = Color(0xFF1E7F4F);
  static const Color incomeDark       = Color(0xFF7BD8A5);
  static const Color expenseLight     = Color(0xFFB4372F);
  static const Color expenseDark      = Color(0xFFF09A93);
  static const Color warningLight     = Color(0xFF9A6700);
  static const Color warningDark      = Color(0xFFF5C842);
  static const Color warningContainerLight = Color(0xFFFFF3CD);
  static const Color warningContainerDark  = Color(0xFF3D2E00);

  // ── Brand gradient (hero surfaces: balance card, primary CTAs) ───────────
  static const Color brandGradientStart = Color(0xFF2B2BE0);
  static const Color brandGradientEnd   = Color(0xFF6D6BF5);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGradientStart, brandGradientEnd],
  );

  // ── Category palette — vivid, distinct colors for per-category identity ──
  // (separate from chartPalette, which is the neutral grayscale ramp used
  // for generic ordered chart slices elsewhere).
  static const List<Color> categoryPalette = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFFEAB308), // yellow
    Color(0xFF84CC16), // lime
    Color(0xFF22C55E), // green
    Color(0xFF10B981), // emerald
    Color(0xFF14B8A6), // teal
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFA855F7), // purple
    Color(0xFFD946EF), // fuchsia
    Color(0xFFEC4899), // pink
    Color(0xFFF43F5E), // rose
  ];

  /// Deterministic hash of a category key → a stable color from
  /// [categoryPalette], so the same category always renders in the same
  /// color across the donut, breakdown list, transaction tiles, and filter
  /// chips.
  static Color categoryColor(String key) {
    final hash = key.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return categoryPalette[hash % categoryPalette.length];
  }
}
