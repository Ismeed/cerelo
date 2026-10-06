import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_spacing.dart';
import '../theme/cerelo_text_styles.dart';

enum CereloButtonVariant { primary, secondary, outlined, ghost }

enum CereloButtonSize { small, medium, large }

/// Cerelo primary action button.
///
/// Supports loading state to prevent duplicate submissions.
/// The loading state automatically disables the button to prevent
/// accidental double-taps on state-changing actions.
class CereloButton extends StatelessWidget {
  const CereloButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CereloButtonVariant.primary,
    this.size = CereloButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final CereloButtonVariant variant;
  final CereloButtonSize size;

  /// When true, shows a loading indicator and disables the button.
  /// Use this to prevent duplicate state-changing submissions.
  final bool isLoading;
  final bool isFullWidth;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final effectiveCallback = isLoading ? null : onPressed;

    final minHeight = switch (size) {
      CereloButtonSize.small => 36.0,
      CereloButtonSize.medium => CereloSpacing.minTouchTarget,
      CereloButtonSize.large => 56.0,
    };

    final textStyle = switch (size) {
      CereloButtonSize.small => CereloTextStyles.labelMd,
      CereloButtonSize.medium => CereloTextStyles.labelLg,
      CereloButtonSize.large => CereloTextStyles.labelLg,
    };

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...
          [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CereloColors.white,
              ),
            ),
            const SizedBox(width: CereloSpacing.sm),
          ]
        else if (leadingIcon != null) ...
          [
            Icon(leadingIcon, size: CereloSpacing.iconMd),
            const SizedBox(width: CereloSpacing.xs),
          ],
        Text(label, style: textStyle),
      ],
    );

    if (isFullWidth) {
      child = SizedBox(width: double.infinity, child: child);
    }

    return switch (variant) {
      CereloButtonVariant.primary => ElevatedButton(
          onPressed: effectiveCallback,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, minHeight),
          ),
          child: child,
        ),
      CereloButtonVariant.secondary => ElevatedButton(
          onPressed: effectiveCallback,
          style: ElevatedButton.styleFrom(
            backgroundColor: CereloColors.navyLight,
            foregroundColor: CereloColors.white,
            minimumSize: Size(0, minHeight),
          ),
          child: child,
        ),
      CereloButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveCallback,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, minHeight),
          ),
          child: child,
        ),
      CereloButtonVariant.ghost => TextButton(
          onPressed: effectiveCallback,
          style: TextButton.styleFrom(
            minimumSize: Size(0, minHeight),
          ),
          child: child,
        ),
    };
  }
}
