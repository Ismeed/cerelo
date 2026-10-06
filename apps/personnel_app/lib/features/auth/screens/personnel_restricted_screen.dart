import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/personnel_router.dart';
import '../providers/personnel_profile_provider.dart';

/// Screen displayed when an authenticated user is not authorized for Personnel operations
/// (e.g. not provisioned in public.personnel, is_active == false, or missing operating_hub_id).
class PersonnelRestrictedScreen extends ConsumerWidget {
  const PersonnelRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(personnelProfileProvider);
    final authService = ref.watch(personnelAuthServiceProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CereloSpacing.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(CereloSpacing.xl),
                  decoration: BoxDecoration(
                    color: CereloColors.white,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                    border: Border.all(color: CereloColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CereloColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 48,
                          color: CereloColors.error,
                        ),
                      ),
                      const SizedBox(height: CereloSpacing.lg),
                      const Text(
                        'Staff Access Unavailable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: CereloColors.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: CereloSpacing.sm),
                      const Text(
                        'This account is not currently authorized for CERELO Personnel operations. Contact your operations administrator.',
                        style: TextStyle(
                          fontSize: 14,
                          color: CereloColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: CereloSpacing.md),
                      profileAsync.when(
                        data: (profile) => Text(
                          profile.email ?? authService.currentUser?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CereloSpacing.xl),
                CereloButton(
                  label: 'Sign Out',
                  variant: CereloButtonVariant.outlined,
                  leadingIcon: Icons.logout_rounded,
                  onPressed: () async {
                    await authService.signOut();
                    ref.invalidate(personnelProfileProvider);
                    if (context.mounted) {
                      context.go(PersonnelRoutes.login);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
