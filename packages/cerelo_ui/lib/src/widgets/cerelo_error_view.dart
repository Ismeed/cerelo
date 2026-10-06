import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_text_styles.dart';
import 'cerelo_button.dart';

/// Standardized error state view.
///
/// Displays a domain-safe error message. Raw technical errors
/// must be sanitized before reaching this widget.
class CereloErrorView extends StatelessWidget {
  const CereloErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please try again. If the problem persists, contact support.',
    this.onRetry,
  });

  final String title;
  final String message;

  /// If provided, shows a Retry button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: CereloColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: CereloTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: CereloTextStyles.bodyMd.copyWith(
                color: CereloColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...
              [
                const SizedBox(height: 24),
                CereloButton(
                  label: 'Try Again',
                  onPressed: onRetry,
                  variant: CereloButtonVariant.outlined,
                  isFullWidth: false,
                ),
              ],
          ],
        ),
      ),
    );
  }
}
