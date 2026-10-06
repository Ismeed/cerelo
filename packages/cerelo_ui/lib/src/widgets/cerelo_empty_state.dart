import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';
import '../theme/cerelo_text_styles.dart';

/// Standardized empty state view for lists and content areas.
class CereloEmptyState extends StatelessWidget {
  const CereloEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: CereloColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: CereloColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: CereloTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: CereloTextStyles.bodyMd.copyWith(
                color: CereloColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...
              [
                const SizedBox(height: 24),
                action!,
              ],
          ],
        ),
      ),
    );
  }
}
