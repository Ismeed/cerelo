import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

/// Help & Support dialog for Cerelo Customer App.
///
/// Features:
/// - Quick FAQ on the Kano ↔ Katsina corridor
/// - Official Cerelo Support Email & Hotline channels
class HelpSupportDialog extends StatelessWidget {
  const HelpSupportDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) => const HelpSupportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CereloSpacing.pagePadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.navy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: CereloSpacing.md),

            // Contact Channels
            Container(
              padding: const EdgeInsets.all(CereloSpacing.md),
              decoration: BoxDecoration(
                color: CereloColors.surfaceVariant,
                borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                border: Border.all(color: CereloColors.border),
              ),
              child: const Column(
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'Support Email',
                    value: 'support@cerelonet.com',
                  ),
                  Divider(),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: 'Operations Hotline',
                    value: '+2349023107077',
                  ),
                  Divider(),
                  _ContactRow(
                    icon: Icons.schedule_outlined,
                    label: 'Operating Hours',
                    value: 'Monday – Saturday: 7:00 AM – 7:00 PM',
                  ),
                ],
              ),
            ),

            const SizedBox(height: CereloSpacing.lg),

            // Frequently Asked Questions
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: CereloSpacing.sm),

            const _FaqItem(
              question: 'Which cities does Cerelo operate in?',
              answer:
                  'Cerelo currently operates intercity door-to-door deliveries exclusively along the Kano ↔ Katsina corridor.',
            ),
            const _FaqItem(
              question: 'How do I pay for my delivery?',
              answer:
                  'Cerelo supports physical cash payments recorded directly by our Personnel at pickup or delivery.',
            ),
            const _FaqItem(
              question: 'How do I track my package?',
              answer:
                  'Use the Delivery Code (e.g. CRL-XXXX-XXXX) in the Shipments tab to view real-time status milestones from pickup to doorstep handover.',
            ),

            const SizedBox(height: CereloSpacing.xl),

            CereloButton(
              label: 'Close',
              variant: CereloButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CereloColors.navy),
          const SizedBox(width: CereloSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CereloColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(CereloSpacing.md),
        decoration: BoxDecoration(
          color: CereloColors.white,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          border: Border.all(color: CereloColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              answer,
              style: const TextStyle(
                fontSize: 12,
                color: CereloColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
