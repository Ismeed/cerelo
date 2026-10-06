import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_spacing.dart';
import '../theme/cerelo_text_styles.dart';

/// A consistent heading for a group of content within a screen.
///
/// The count pill is deliberately neutral rather than brand-orange: orange is
/// the action color, and spending it on decoration is what made earlier screens
/// read as noisy. If everything shouts, the actual buttons stop standing out.
class CereloSectionHeader extends StatelessWidget {
  const CereloSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.count,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CereloSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: CereloSpacing.iconMd, color: CereloColors.textSecondary),
            const SizedBox(width: CereloSpacing.sm),
          ],
          Flexible(
            child: Text(
              title,
              style: CereloTextStyles.h3.copyWith(color: CereloColors.navy),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: CereloSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusFull),
              ),
              child: Text(
                '$count',
                style: CereloTextStyles.labelMd.copyWith(color: CereloColors.navy),
              ),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
