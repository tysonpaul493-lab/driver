import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../dashboard/screens/driver_dashboard_screen.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/otp_bars_widget.dart';
import '../../../core/services/firebase_phone_auth_service.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit SMS verification code'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    // 1. Verify with Firebase Phone Auth
    await FirebasePhoneAuthService.verifySmsCode(smsCode: otp);

    // 2. Authenticate driver session
    final success = await ref.read(authNotifierProvider.notifier).verifyOtp(otp);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase phone authentication verified successfully!'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0) return;
    await ref.read(authNotifierProvider.notifier).sendOtp(widget.phoneNumber);
    _startCountdown();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Real SMS OTP requested for ${widget.phoneNumber} via Firebase'),
          backgroundColor: AppColors.ambulanceTeal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SMS Code Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Firebase Phone Auth Badge
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ambulanceTeal.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.ambulanceTeal,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF57C00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: Color(0xFFF57C00), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Firebase Phone Auth',
                          style: TextStyle(
                            color: Color(0xFFF57C00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Enter Real SMS OTP',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit verification code received on your phone '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' to verify and sign in as Ambulance Driver:'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 6-Digit Segmented OTP Bars (Clean manual input)
              DriverOtpBarsWidget(
                controller: _otpController,
                focusNode: _otpFocusNode,
                length: 6,
                autoFocus: true,
                activeBorderColor: AppColors.ambulanceTeal,
                inactiveBorderColor: AppColors.borderDark,
                filledColor: AppColors.cardDark,
                onCompleted: (code) {
                  if (code.length == 6 && !authState.isLoading) {
                    _handleVerify();
                  }
                },
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22E63946),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emergencyRed, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.emergencyRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Prominent Verify & Submit Button
              CustomButton(
                label: 'VERIFY & SUBMIT OTP',
                icon: Icons.verified_user_rounded,
                isLoading: authState.isLoading,
                onPressed: _handleVerify,
              ),

              const SizedBox(height: 24),

              // Resend OTP Countdown
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in ${_secondsRemaining}s',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _handleResend,
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.ambulanceTeal, size: 18),
                        label: const Text(
                          'Resend SMS Code',
                          style: TextStyle(
                            color: AppColors.ambulanceTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
