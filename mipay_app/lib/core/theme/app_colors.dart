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
}
