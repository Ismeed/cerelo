import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';

/// Onboarding Step 1: Account Classification (Individual vs Business).
///
/// LOCKED REQUIREMENT:
/// - Exactly two classifications: Individual and Business.
/// - Individual completes onboarding immediately.
/// - Business proceeds to Step 2 to enter Business/Shop Name.
class AccountTypeScreen extends ConsumerStatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  ConsumerState<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends ConsumerState<AccountTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  AccountType _selectedType = AccountType.individual;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(customerAuthProvider);
    final initialName = authState.profile?.fullName ??
        authState.pendingFullName ??
        authState.user?.fullName ??
        '';
    _fullNameController.text = initialName;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(customerAuthProvider.notifier);
    final fullName = _fullNameController.text.trim();

    if (_selectedType == AccountType.individual) {
      try {
        await notifier.completeOnboarding(
          accountType: AccountType.individual,
          fullName: fullName.isNotEmpty ? fullName : null,
        );
      } catch (_) {
        // Error display handled by authState.errorMessage
      }
    } else {
      context.push(
        AppRoutes.onboardingBusinessName,
        extra: fullName.isNotEmpty ? fullName : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Account Setup'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(customerAuthProvider.notifier).signOut();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: CereloColors.textOnDark),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: CereloSpacing.pagePadding,
            vertical: CereloSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress Indicator
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: CereloColors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _selectedType == AccountType.business
                              ? CereloColors.orange.withOpacity(0.3)
                              : CereloColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Header
                const Text(
                  'How will you use Cerelo?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.navy,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your account type to configure parcel labeling and receipts.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CereloColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

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
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        color: CereloColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: CereloSpacing.md),
                ],

                // Full Name Field
                CereloTextField(
                  label: 'Full Name',
                  hint: 'e.g. Aminu Bello',
                  controller: _fullNameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: CereloColors.textTertiary,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name.';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters.';
                    }
                    if (value.trim().length > 100) {
                      return 'Name must be 100 characters or fewer.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Account Type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CereloColors.navy,
                  ),
                ),
                const SizedBox(height: 8),

                // Option 1: Individual
                _AccountTypeCard(
                  title: 'Individual',
                  description:
                      'For personal parcel sending, family packages, and occasional shipments.',
                  icon: Icons.person_rounded,
                  isSelected: _selectedType == AccountType.individual,
                  onTap: () {
                    setState(() => _selectedType = AccountType.individual);
                  },
                ),

                const SizedBox(height: CereloSpacing.md),

                // Option 2: Business
                _AccountTypeCard(
                  title: 'Business / Merchant',
                  description:
                      'For market traders, shop owners, and commercial goods delivery between Kano and Katsina.',
                  icon: Icons.storefront_rounded,
                  isSelected: _selectedType == AccountType.business,
                  onTap: () {
                    setState(() => _selectedType = AccountType.business);
                  },
                ),

                const SizedBox(height: 36),

                // Action button
                CereloButton(
                  label: _selectedType == AccountType.individual
                      ? 'Complete Setup'
                      : 'Continue',
                  isLoading: authState.isActionLoading,
                  onPressed: authState.isActionLoading ? null : _handleContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(CereloSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? CereloColors.white : CereloColors.surface,
          borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? CereloColors.navy : CereloColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CereloColors.navy.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? CereloColors.navy
                    : CereloColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(CereloSpacing.radiusSm),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? CereloColors.white
                    : CereloColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: CereloSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? CereloColors.navy
                              : CereloColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: CereloColors.orange,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CereloColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
