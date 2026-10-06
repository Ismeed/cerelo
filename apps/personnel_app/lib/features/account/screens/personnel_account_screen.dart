import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local/personnel_local_db.dart';
import '../../../core/router/personnel_router.dart';
import '../../auth/providers/personnel_profile_provider.dart';

/// Personnel Account & Dynamic Hub Profile screen.
class PersonnelAccountScreen extends ConsumerWidget {
  const PersonnelAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(personnelProfileProvider);
    final authService = ref.watch(personnelAuthServiceProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(title: const Text('Staff Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(personnelProfileProvider);
            await ref.read(personnelProfileProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(CereloSpacing.pagePadding),
            child: profileAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(CereloSpacing.lg),
                decoration: BoxDecoration(
                  color: CereloColors.white,
                  borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: CereloColors.error, size: 36),
                    const Text(
                      'Could not refresh profile. Please check your connection.',
                      style: TextStyle(
                        fontSize: 13,
                        color: CereloColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: CereloSpacing.md),
                    CereloButton(
                      label: 'Retry',
                      variant: CereloButtonVariant.outlined,
                      onPressed: () => ref.invalidate(personnelProfileProvider),
                    ),
                  ],
                ),
              ),
              data: (profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Summary Card
                  Container(
                    padding: const EdgeInsets.all(CereloSpacing.lg),
                    decoration: BoxDecoration(
                      color: CereloColors.white,
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusLg),
                      border: Border.all(color: CereloColors.border),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: CereloColors.navy.withOpacity(0.1),
                          child: const Icon(
                            Icons.person_rounded,
                            color: CereloColors.navy,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: CereloSpacing.md),
                        Text(
                          profile.fullName ?? 'Cerelo Field Staff',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CereloColors.navy,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email ??
                              authService.currentUser?.email ??
                              '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: CereloColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CereloSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: profile.isActive
                                ? CereloColors.success.withOpacity(0.12)
                                : CereloColors.error.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(CereloSpacing.radiusSm),
                          ),
                          child: Text(
                            profile.isActive
                                ? 'ACTIVE PERSONNEL'
                                : 'INACTIVE ACCOUNT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: profile.isActive
                                  ? CereloColors.success
                                  : CereloColors.error,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: CereloSpacing.lg),

                  // Operating Scope Card
                  Container(
                    padding: const EdgeInsets.all(CereloSpacing.md),
                    decoration: BoxDecoration(
                      color: CereloColors.white,
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusMd),
                      border: Border.all(color: CereloColors.border),
                    ),
                    child: Column(
                      children: [
                        _AccountRow(
                          label: 'Assigned Hub',
                          value: profile.hubDisplay,
                        ),
                        const Divider(),
                        _AccountRow(
                          label: 'Staff Phone',
                          value: profile.phoneNumber ?? 'Not provided',
                        ),
                        if (profile.employeeReference != null &&
                            profile.employeeReference!.isNotEmpty) ...[
                          const Divider(),
                          _AccountRow(
                            label: 'Employee Ref',
                            value: profile.employeeReference!,
                          ),
                        ],
                        const Divider(),
                        const _AccountRow(
                          label: 'Corridor',
                          value: 'Kano ↔ Katsina (V1 Intercity)',
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
                    onPressed: () async {
                      final currentUserId = CereloSupabaseClient.instance.auth.currentUser?.id;
                      if (currentUserId != null) {
                        await PersonnelLocalDb.instance.clearSensitiveData(currentUserId);
                      }
                      await authService.signOut();
                      ref.invalidate(personnelProfileProvider);
                      if (context.mounted) {
                        context.go(PersonnelRoutes.login);
                      }
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CereloColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CereloColors.navy,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
