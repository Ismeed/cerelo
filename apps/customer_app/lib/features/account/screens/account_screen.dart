import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../dialogs/help_support_dialog.dart';

/// Customer Account Screen — displays authenticated profile information,
/// profile editing modal, help & support, and secure sign out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  void _showEditProfileSheet(BuildContext context, WidgetRef ref) {
    final profile = ref.read(customerAuthProvider).profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.fullName);
    final businessNameController =
        TextEditingController(text: profile.businessName ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: CereloSpacing.pagePadding,
            right: CereloSpacing.pagePadding,
            top: CereloSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: CereloSpacing.md),
                CereloTextField(
                  label: 'Full Name',
                  controller: nameController,
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Name must be at least 2 characters.';
                    }
                    if (value.trim().length > 100) {
                      return 'Name must be 100 characters or fewer.';
                    }
                    return null;
                  },
                ),
                if (profile.isBusiness) ...[
                  const SizedBox(height: CereloSpacing.md),
                  CereloTextField(
                    label: 'Business / Shop Name',
                    controller: businessNameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Business name cannot be empty.';
                      }
                      if (value.trim().length < 2) {
                        return 'Business name must be at least 2 characters.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: CereloSpacing.lg),
                CereloButton(
                  label: 'Save Changes',
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final notifier = ref.read(customerAuthProvider.notifier);
                    try {
                      await notifier.updateProfile(
                        fullName: nameController.text.trim(),
                        businessName: profile.isBusiness
                            ? businessNameController.text.trim()
                            : null,
                      );
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully.'),
                            backgroundColor: CereloColors.navy,
                          ),
                        );
                      }
                    } catch (_) {
                      // Error handled by state
                    }
                  },
                ),
                const SizedBox(height: CereloSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyTermsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CereloColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CereloSpacing.radiusLg),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Privacy & Terms',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
                const Text(
                  'Cerelo V1 operates under the logistics transport regulations of Nigeria. Parcel custody handoffs are cryptographically logged and audited for sender and receiver protection. Receiver tracking links expose only masked recipient details and status timelines to protect customer PII.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CereloColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: CereloSpacing.lg),
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
      },
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out of your Cerelo account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(customerAuthProvider.notifier).signOut();
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: CereloColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthProvider);
    final profile = authState.profile;

    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Cerelo Customer';
    final email = profile?.email ?? authState.user?.email ?? '—';
    final isBusiness = profile?.isBusiness ?? false;
    final businessName = profile?.businessName;

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('My Account'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CereloSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Summary Card
              Container(
                padding: const EdgeInsets.all(CereloSpacing.lg),
                decoration: BoxDecoration(
                  color: CereloColors.white,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                  border: Border.all(color: CereloColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar circle with initial
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: CereloColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: CereloColors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.md),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: CereloColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CereloColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CereloSpacing.md),

                    // Account Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CereloSpacing.md,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isBusiness
                            ? CereloColors.orange.withOpacity(0.12)
                            : CereloColors.navy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(
                          CereloSpacing.radiusFull,
                        ),
                      ),
                      child: Text(
                        isBusiness ? 'Business Account' : 'Individual Account',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isBusiness
                              ? CereloColors.orangeDark
                              : CereloColors.navy,
                        ),
                      ),
                    ),

                    if (isBusiness && businessName != null) ...[
                      const SizedBox(height: CereloSpacing.sm),
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.textPrimary,
                        ),
                      ),
                    ],

                    const SizedBox(height: CereloSpacing.md),
                    const Divider(),
                    const SizedBox(height: CereloSpacing.xs),

                    // Edit Profile Button
                    TextButton.icon(
                      onPressed: () => _showEditProfileSheet(context, ref),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: CereloColors.navy,
                      ),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: CereloColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.lg),

              // Corridor Info Tile
              Container(
                padding: const EdgeInsets.all(CereloSpacing.md),
                decoration: BoxDecoration(
                  color: CereloColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  border: Border.all(color: CereloColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.route_rounded,
                      color: CereloColors.navy,
                      size: 20,
                    ),
                    SizedBox(width: CereloSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Operating Corridor',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CereloColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Kano ↔ Katsina (Intercity)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CereloColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.lg),

              // Action Tiles: Help & Privacy
              Container(
                decoration: BoxDecoration(
                  color: CereloColors.white,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
                  border: Border.all(color: CereloColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.help_outline_rounded,
                        color: CereloColors.navy,
                      ),
                      title: const Text(
                        'Help & Support',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'FAQ & Operations Hotline',
                        style: TextStyle(
                          fontSize: 12,
                          color: CereloColors.textTertiary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: CereloColors.textTertiary,
                      ),
                      onTap: () => HelpSupportDialog.show(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.shield_outlined,
                        color: CereloColors.navy,
                      ),
                      title: const Text(
                        'Privacy & Delivery Policies',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CereloColors.textPrimary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: CereloColors.textTertiary,
                      ),
                      onTap: () => _showPrivacyTermsSheet(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CereloSpacing.xl),

              // Sign Out Button
              CereloButton(
                label: 'Sign Out',
                variant: CereloButtonVariant.outlined,
                leadingIcon: Icons.logout_rounded,
                onPressed: () => _showSignOutDialog(context, ref),
              ),

              const SizedBox(height: CereloSpacing.lg),

              const Text(
                'Cerelo V1 · Kano ↔ Katsina Doorstep Logistics',
                style: TextStyle(
                  fontSize: 11,
                  color: CereloColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
