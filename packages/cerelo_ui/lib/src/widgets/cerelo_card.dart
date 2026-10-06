import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_elevation.dart';
import '../theme/cerelo_spacing.dart';

/// The standard Cerelo content surface.
///
/// Screens previously hand-rolled `Container`s with a hairline border and no
/// elevation, which left every card looking flat against the near-white page.
/// This centralises the surface treatment so cards read consistently and
/// tappable ones get a real ripple and touch target.
class CereloCard extends StatelessWidget {
  const CereloCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CereloSpacing.md),
    this.margin,
    this.onTap,
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Draws the card with a brand-tinted border, for the one item on screen that
  /// needs the operator's attention. Use sparingly — if everything is
  /// emphasized, nothing is.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CereloSpacing.radiusLg);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: CereloColors.white,
        borderRadius: radius,
        border: Border.all(
          color: emphasized
              ? CereloColors.orange.withOpacity(0.35)
              : CereloColors.border,
        ),
        boxShadow: CereloElevation.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
