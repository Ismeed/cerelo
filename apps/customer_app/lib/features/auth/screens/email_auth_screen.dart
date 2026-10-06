import 'dart:async';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

/// Passwordless Email OTP authentication screen for Cerelo Customer registration and sign-in.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
      }
    });
  }

  Future<void> _requestOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final notifier = ref.read(customerAuthProvider.notifier);
    final email = _emailController.text.trim();

    try {
      await notifier.requestEmailOtp(email: email);
      _startResendTimer();
    } catch (_) {
      // Error message is presented via authState.errorMessage
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    final notifier = ref.read(customerAuthProvider.notifier);
    final token = _otpController.text.trim();

    try {
      await notifier.verifyEmailOtp(token: token);
    } catch (_) {
      // Error message is presented via authState.errorMessage
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final notifier = ref.read(customerAuthProvider.notifier);
    try {
      await notifier.resendEmailOtp();
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new verification code has been sent.'),
            backgroundColor: CereloColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // Error message is presented via authState.errorMessage
    }
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    _otpController.clear();
    ref.read(customerAuthProvider.notifier).resetEmailOtp();
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(customerAuthProvider);

    return Scaffold(
      backgroundColor: CereloColors.surface,
      appBar: AppBar(
        title: Text(authState.isOtpSent ? 'Verify Code' : 'Continue with Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (authState.isOtpSent) {
              _changeEmail();
            } else {
              context.go(AppRoutes.login);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: CereloSpacing.pagePadding,
            vertical: CereloSpacing.lg,
          ),
          child: authState.isOtpSent
              ? _buildOtpVerificationView(authState)
              : _buildEmailRequestView(authState),
        ),
      ),
    );
  }

  Widget _buildEmailRequestView(CustomerAuthState authState) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Continue with Email',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: CereloColors.navy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: CereloSpacing.xs),
          const Text(
            'Enter your email address to receive a secure 6-digit verification code.',
            style: TextStyle(
              fontSize: 14,
              color: CereloColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: CereloSpacing.xl),

          // Error message banner
          if (authState.errorMessage != null) ...[
            _buildErrorBanner(authState.errorMessage!),
            const SizedBox(height: CereloSpacing.lg),
          ],

          // Email Field
          CereloTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: CereloColors.textTertiary,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address.';
              }
              final email = value.trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: CereloSpacing.xl),

          // Continue Button
          CereloButton(
            label: 'Continue',
            isLoading: authState.isActionLoading,
            onPressed: authState.isActionLoading ? null : _requestOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView(CustomerAuthState authState) {
    final email = authState.pendingEmail ?? _emailController.text.trim();
    final maskedEmail = _maskEmail(email);

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CereloColors.navy,
            ),
          ),
          const SizedBox(height: CereloSpacing.xs),
          Text(
            'We sent a 6-digit code to $maskedEmail',
            style: const TextStyle(
              fontSize: 14,
              color: CereloColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: CereloSpacing.xl),

          // Error message banner
          if (authState.errorMessage != null) ...[
            _buildErrorBanner(authState.errorMessage!),
            const SizedBox(height: CereloSpacing.lg),
          ],

          // OTP Code Field
          CereloTextField(
            label: '6-Digit Code',
            hint: '123456',
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(
              Icons.pin_outlined,
              color: CereloColors.textTertiary,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the verification code.';
              }
              final clean = value.trim();
              if (clean.length < 6 || clean.length > 8 || int.tryParse(clean) == null) {
                return 'Code must be 6 to 8 digits.';
              }
              return null;
            },
          ),
          const SizedBox(height: CereloSpacing.xl),

          // Verify Button
          CereloButton(
            label: 'Verify & Continue',
            isLoading: authState.isActionLoading,
            onPressed: authState.isActionLoading ? null : _verifyOtp,
          ),

          const SizedBox(height: CereloSpacing.lg),

          // Resend Code and Timer
          Center(
            child: _canResend
                ? TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Resend Code'),
                    style: TextButton.styleFrom(
                      foregroundColor: CereloColors.success,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: authState.isActionLoading ? null : _resendOtp,
                  )
                : Text(
                    'Resend code in ${_resendCountdown}s',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CereloColors.textSecondary,
                    ),
                  ),
          ),

          const SizedBox(height: CereloSpacing.xs),

          // Change Email Button
          Center(
            child: TextButton(
              onPressed: authState.isActionLoading ? null : _changeEmail,
              child: const Text(
                'Use a different email address',
                style: TextStyle(
                  fontSize: 13,
                  color: CereloColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.md),
      decoration: BoxDecoration(
        color: CereloColors.errorLight,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusMd),
        border: Border.all(color: CereloColors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: CereloColors.error,
            size: 20,
          ),
          const SizedBox(width: CereloSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: CereloColors.error,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
