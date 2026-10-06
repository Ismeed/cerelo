import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_spacing.dart';
import '../theme/cerelo_text_styles.dart';

/// A compact "nothing here" state for a section inside a busy screen.
///
/// Distinct from CereloEmptyState, which centers a large illustration for a
/// whole empty page. On an operations dashboard several sections can be empty at
/// once, and full-size empty states pushed the real work off the screen — so
/// this one stays quiet and short.
class CereloInlineEmpty extends StatelessWidget {
  const CereloInlineEmpty({
    super.key,
    required this.message,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: CereloSpacing.md,
        vertical: CereloSpacing.md,
      ),
      decoration: BoxDecoration(
        color: CereloColors.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: CereloSpacing.iconMd, color: CereloColors.textTertiary),
          const SizedBox(width: CereloSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: CereloTextStyles.bodySm.copyWith(color: CereloColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
