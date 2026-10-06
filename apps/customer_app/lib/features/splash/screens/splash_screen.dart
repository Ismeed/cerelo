import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

/// Branded splash & transition screen.
///
/// Displayed during app launch while session and customer profile are being resolved.
/// Prevents UI routing flicker (showing Home or Login before auth status is known).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthProvider);

    return Scaffold(
      backgroundColor: CereloColors.navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CereloSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand mark
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: CereloColors.white,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: CereloColors.navy,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: CereloSpacing.lg),
                const Text(
                  'Cerelo',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: CereloSpacing.xs),
                Text(
                  'Kano ↔ Katsina Parcel Logistics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CereloColors.white.withOpacity(0.7),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 48),

                // If an error occurred while loading profile
                if (authState.status == CustomerAuthStatus.error) ...[
                  Container(
                    padding: const EdgeInsets.all(CereloSpacing.md),
                    decoration: BoxDecoration(
                      color: CereloColors.error.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(CereloSpacing.radiusMd),
                      border: Border.all(
                        color: CereloColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(height: CereloSpacing.sm),
                        Text(
                          authState.errorMessage ??
                              'Could not connect to Cerelo servers.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: CereloSpacing.md),
                        CereloButton(
                          label: 'Retry Connection',
                          onPressed: () {
                            ref
                                .read(customerAuthProvider.notifier)
                                .retryProfileResolution();
                          },
                          variant: CereloButtonVariant.primary,
                        ),
                        const SizedBox(height: CereloSpacing.xs),
                        CereloButton(
                          label: 'Sign Out',
                          onPressed: () {
                            ref.read(customerAuthProvider.notifier).signOut();
                          },
                          variant: CereloButtonVariant.ghost,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: CereloColors.orange,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
