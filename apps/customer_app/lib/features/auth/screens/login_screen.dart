import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:customer_app/core/router/app_router.dart';
import '../providers/auth_provider.dart';

/// Primary customer authentication entry screen.
///
/// Presents the two approved V1 login methods:
/// - Continue with Google
/// - Continue with Email
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthProvider);
    final notifier = ref.read(customerAuthProvider.notifier);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: CereloSpacing.pagePadding,
            vertical: CereloSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Brand Hero Header
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CereloColors.navy,
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                  child: const Center(
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: CereloColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CereloSpacing.md),
              const Text(
                'Cerelo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: CereloColors.navy,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CereloSpacing.xs),
              const Text(
                'Door-to-door parcel delivery\nKano ↔ Katsina',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: CereloColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 56),

              // Error display if any
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(CereloSpacing.md),
                  decoration: BoxDecoration(
                    color: CereloColors.errorLight,
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusMd),
                    border: Border.all(color: CereloColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: CereloColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: CereloSpacing.sm),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            color: CereloColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: CereloColors.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => notifier.clearError(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CereloSpacing.lg),
              ],

              // Google Sign-In Button
              OutlinedButton(
                onPressed: authState.isActionLoading
                    ? null
                    : () {
                        notifier.signInWithGoogle();
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: CereloColors.white,
                  side: const BorderSide(color: CereloColors.border),
                  padding: const EdgeInsets.symmetric(
                    vertical: CereloSpacing.md,
                    horizontal: CereloSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(CereloSpacing.radiusMd),
                  ),
                ),
                child: authState.isActionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CereloColors.navy,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CereloColors.navy,
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: CereloSpacing.md),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CereloColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: CereloSpacing.md),

              // Email Sign-In Button
              CereloButton(
                label: 'Continue with Email',
                variant: CereloButtonVariant.secondary,
                leadingIcon: Icons.mail_outline_rounded,
                onPressed: () {
                  context.go(AppRoutes.emailAuth);
                },
              ),

              const SizedBox(height: 48),

              // Terms & Privacy Microcopy
              Text(
                'By continuing, you agree to Cerelo\'s terms of service and delivery policies for the Kano ↔ Katsina corridor.',
                style: TextStyle(
                  fontSize: 12,
                  color: CereloColors.textTertiary.withOpacity(0.8),
                  height: 1.4,
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
