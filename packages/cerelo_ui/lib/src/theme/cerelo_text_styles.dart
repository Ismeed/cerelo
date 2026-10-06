import 'package:flutter/material.dart';
import 'cerelo_colors.dart';

/// Cerelo typography system.
///
/// Uses Inter (sans-serif) for UI and a higher-contrast hierarchy.
/// Optimized for legibility on mid-range Android screens.
abstract final class CereloTextStyles {
  // ─── Display ──────────────────────────────────────────────────────────────

  static const TextStyle displayLg = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72,
    height: 1.2,
    color: CereloColors.textPrimary,
  );

  static const TextStyle displaySm = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.25,
    color: CereloColors.textPrimary,
  );

  // ─── Headings ─────────────────────────────────────────────────────────────

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.48,
    height: 1.3,
    color: CereloColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.35,
    color: CereloColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.36,
    height: 1.4,
    color: CereloColors.textPrimary,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────

  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: CereloColors.textPrimary,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: CereloColors.textPrimary,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: CereloColors.textSecondary,
  );

  // ─── Labels ───────────────────────────────────────────────────────────────

  static const TextStyle labelLg = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: CereloColors.textPrimary,
  );

  static const TextStyle labelMd = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: CereloColors.textSecondary,
  );

  static const TextStyle labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
    color: CereloColors.textTertiary,
  );

  // ─── Delivery Code ────────────────────────────────────────────────────────

  /// Monospace style for Delivery Code display.
  static const TextStyle deliveryCode = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: 'monospace',
    letterSpacing: 2.0,
    color: CereloColors.navy,
  );
}
