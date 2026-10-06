import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_spacing.dart';
import '../theme/cerelo_text_styles.dart';

/// Reusable banner displayed when a state-changing mutation encounters a network
/// timeout or uncertain response, preventing personnel or customers from repeating
/// high-risk operations (e.g. collecting physical cash twice).
class CereloUnknownOutcomeBanner extends StatelessWidget {
  const CereloUnknownOutcomeBanner({
    super.key,
    required this.title,
    required this.message,
    required this.onVerifyState,
    this.isChecking = false,
  });

  /// Short headline explaining what action outcome is currently being checked.
  final String title;

  /// Human-readable explanation guiding the user not to duplicate physical actions.
  final String message;

  /// Callback to safely poll or replay the idempotent command.
  final VoidCallback onVerifyState;

  /// Whether the verification query is actively running.
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.warningLight,
        border: Border.all(color: CereloColors.warning),
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sync_problem_rounded,
                color: CereloColors.warning,
                size: 20,
              ),
              const SizedBox(width: CereloSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: CereloTextStyles.labelMd.copyWith(
                    color: CereloColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CereloSpacing.xs),
          Text(
            message,
            style: CereloTextStyles.bodySm.copyWith(
              color: CereloColors.textSecondary,
            ),
          ),
          const SizedBox(height: CereloSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isChecking ? null : onVerifyState,
              icon: isChecking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CereloColors.warning,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isChecking ? 'Checking status...' : 'Verify Status'),
              style: TextButton.styleFrom(
                foregroundColor: CereloColors.warning,
                textStyle: CereloTextStyles.labelSm.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
