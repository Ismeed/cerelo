import 'package:cerelo_core/cerelo_core.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

/// Onboarding Step 2: Business / Shop Name Collection.
///
/// Only shown to customers who selected the Business account classification.
/// Atomically saves the business name and finishes onboarding.
class BusinessNameScreen extends ConsumerStatefulWidget {
  const BusinessNameScreen({this.fullName, super.key});

  final String? fullName;

  @override
  ConsumerState<BusinessNameScreen> createState() => _BusinessNameScreenState();
}

class _BusinessNameScreenState extends ConsumerState<BusinessNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(customerAuthProvider.notifier);
    final businessName = _businessNameController.text.trim();

    try {
      await notifier.completeOnboarding(
        accountType: AccountType.business,
        businessName: businessName,
        fullName: widget.fullName,
      );
    } catch (_) {
      // Error is displayed via authState.errorMessage
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: const Text('Business Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                          color: CereloColors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Header
                const Text(
                  'What is your business or shop name?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.navy,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This name will appear on parcel labels, receipts, and delivery updates for your customers.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CereloColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 32),

                // Error banner
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
                  const SizedBox(height: CereloSpacing.lg),
                ],

                // Business Name Field
                CereloTextField(
                  label: 'Business / Shop Name',
                  hint: 'e.g. Kwari Fabrics & Tailoring',
                  controller: _businessNameController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(
                    Icons.storefront_outlined,
                    color: CereloColors.textTertiary,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your business or shop name.';
                    }
                    if (value.trim().length < 2) {
                      return 'Business name must be at least 2 characters.';
                    }
                    if (value.trim().length > 100) {
                      return 'Business name must be 100 characters or fewer.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 48),

                // Complete Setup button
                CereloButton(
                  label: 'Complete Setup',
                  isLoading: authState.isActionLoading,
                  onPressed: authState.isActionLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
