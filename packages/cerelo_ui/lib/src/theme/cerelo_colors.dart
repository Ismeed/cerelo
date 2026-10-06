import 'package:flutter/material.dart';

/// Cerelo brand color palette.
///
/// Design direction: Premium, modern, trustworthy.
/// Primary: Deep Navy (#1A2B4A)
/// Accent: Vibrant Orange (#F4630A)
/// Surface: Clean White (#FAFAFA)
abstract final class CereloColors {
  // ─── Brand Primary ────────────────────────────────────────────────────────

  /// Deep navy — primary brand identity color.
  static const Color navy = Color(0xFF1A2B4A);
  static const Color navyLight = Color(0xFF2C4270);
  static const Color navyDark = Color(0xFF0E1B30);

  // ─── Brand Accent ─────────────────────────────────────────────────────────

  /// Vibrant orange — action and highlight color.
  static const Color orange = Color(0xFFF4630A);
  static const Color orangeLight = Color(0xFFFF8534);
  static const Color orangeDark = Color(0xFFBF4B00);

  // ─── Neutrals ─────────────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceVariant = Color(0xFFF2F4F7);
  static const Color border = Color(0xFFE4E7EC);
  static const Color borderStrong = Color(0xFFD0D5DD);

  // ─── Text ─────────────────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textTertiary = Color(0xFF98A2B3);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnOrange = Color(0xFFFFFFFF);

  // ─── Status ───────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF12B76A);
  static const Color successLight = Color(0xFFECFDF3);
  static const Color warning = Color(0xFFF79009);
  static const Color warningLight = Color(0xFFFFFAEB);
  static const Color error = Color(0xFFF04438);
  static const Color errorLight = Color(0xFFFEF3F2);
  static const Color info = Color(0xFF0BA5EC);
  static const Color infoLight = Color(0xFFF0F9FF);

  // ─── Shimmer / Skeleton ───────────────────────────────────────────────────

  static const Color shimmerBase = Color(0xFFEEEEEE);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
