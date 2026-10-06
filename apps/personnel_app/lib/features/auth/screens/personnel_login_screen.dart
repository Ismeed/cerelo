import 'dart:async';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/personnel_router.dart';
import '../providers/personnel_profile_provider.dart';

/// Personnel V1 Login Screen — Passwordless 6-Digit Email OTP only.
class PersonnelLoginScreen extends ConsumerStatefulWidget {
  const PersonnelLoginScreen({super.key});

  @override
  ConsumerState<PersonnelLoginScreen> createState() =>
      _PersonnelLoginScreenState();
}

enum _AuthStep { email, otp }

class _PersonnelLoginScreenState extends ConsumerState<PersonnelLoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  _AuthStep _currentStep = _AuthStep.email;
  bool _isLoading = false;
  String? _errorMessage;

  // 60-second resend countdown timer
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name.substring(0, 1)}***${name.substring(name.length - 1)}@$domain';
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid staff email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(personnelAuthServiceProvider);
      // shouldCreateUser: false ensures random emails don't create auth users
      await authService.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = _AuthStep.otp;
          _errorMessage = null;
        });
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is CereloApiError
              ? e.message
              : 'Unable to send verification code. Please check your staff email.';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(personnelAuthServiceProvider);
      await authService.verifyOtp(
        email: email,
        token: otp,
      );

      // Invalidate profile cache and resolve authoritative authorization
      ref.invalidate(personnelProfileProvider);
      final profile = await ref.read(personnelProfileProvider.future);

      if (mounted) {
        setState(() => _isLoading = false);
        if (profile.isAuthorized) {
          context.go(PersonnelRoutes.home);
        } else {
          context.go(PersonnelRoutes.restricted);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is CereloApiError
              ? e.message
              : 'Invalid or expired verification code.';
        });
      }
    }
  }

  void _handleChangeEmail() {
    _countdownTimer?.cancel();
    setState(() {
      _currentStep = _AuthStep.email;
      _otpController.clear();
      _errorMessage = null;
      _resendCountdown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CereloColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CereloSpacing.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                const Center(
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: CereloColors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: CereloSpacing.md),
                const Text(
                  'CERELO Personnel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: CereloColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Internal Field Operations & Hub Terminal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: CereloSpacing.xxl),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(CereloSpacing.lg),
                  decoration: BoxDecoration(
                    color: CereloColors.white,
                    borderRadius: BorderRadius.circular(CereloSpacing.radiusLg),
                  ),
                  child: _currentStep == _AuthStep.email
                      ? _buildEmailStep()
                      : _buildOtpStep(),
                ),

                const SizedBox(height: CereloSpacing.xl),

                const Text(
                  'Personnel accounts are provisioned internally by Cerelo Hub Administrators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Staff Sign In',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: CereloColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter your registered Cerelo staff email to receive a 6-digit login code.',
          style: TextStyle(
            fontSize: 12,
            color: CereloColors.textSecondary,
          ),
        ),
        const SizedBox(height: CereloSpacing.md),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: CereloSpacing.sm),
        ],

        CereloTextField(
          label: 'Staff Email Address',
          hintText: 'e.g. staff.kano@cerelo.ng',
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),

        const SizedBox(height: CereloSpacing.lg),

        CereloButton(
          label: 'Continue',
          isLoading: _isLoading,
          variant: CereloButtonVariant.primary,
          leadingIcon: Icons.arrow_forward_rounded,
          onPressed: _handleSendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final email = _emailController.text.trim();
    final masked = _maskEmail(email);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter 6-Digit Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: CereloColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'We sent a 6-digit code to $masked.',
          style: const TextStyle(
            fontSize: 12,
            color: CereloColors.textSecondary,
          ),
        ),
        const SizedBox(height: CereloSpacing.md),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: CereloSpacing.sm),
        ],

        CereloTextField(
          label: '6-Digit Verification Code',
          hintText: '123456',
          keyboardType: TextInputType.number,
          controller: _otpController,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),

        const SizedBox(height: CereloSpacing.md),

        CereloButton(
          label: 'Verify & Sign In',
          isLoading: _isLoading,
          variant: CereloButtonVariant.primary,
          leadingIcon: Icons.verified_user_rounded,
          onPressed: _handleVerifyOtp,
        ),

        const SizedBox(height: CereloSpacing.sm),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _handleChangeEmail,
              child: const Text(
                'Change Email',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CereloColors.navy,
                ),
              ),
            ),
            if (_resendCountdown > 0)
              Text(
                'Resend in ${_resendCountdown}s',
                style: const TextStyle(
                  fontSize: 12,
                  color: CereloColors.textSecondary,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _handleSendOtp,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CereloColors.orangeDark,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(CereloSpacing.sm),
      decoration: BoxDecoration(
        color: CereloColors.errorLight,
        borderRadius: BorderRadius.circular(CereloSpacing.radiusSm),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: CereloColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
