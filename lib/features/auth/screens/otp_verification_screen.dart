import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../dashboard/screens/driver_dashboard_screen.dart';
import '../providers/auth_provider.dart';

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
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _showAutofillPop = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _otpFocusNode.addListener(() {
      if (_otpFocusNode.hasFocus && _otpController.text.isEmpty) {
        setState(() => _showAutofillPop = true);
      }
    });
  }

  void _startCountdown() {
    _secondsRemaining = 30;
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
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete OTP')),
      );
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).verifyOtp(otp);
    if (success && mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ambulanceTeal.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.ambulanceTeal,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                authState.isDriverRegistered ? 'Welcome Back, Pilot!' : 'Enter Verification Code',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  children: [
                    TextSpan(
                      text: authState.isDriverRegistered
                          ? 'Recognized registered ambulance account for '
                          : 'We sent a 6-digit verification code to ',
                    ),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '. Enter it below to sign in:'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Auto-fill suggestion pop bar (appears after SMS is received when tapping/clicking the OTP bar)
              if ((_showAutofillPop || _otpFocusNode.hasFocus) &&
                  authState.lastGeneratedOtp != null &&
                  _otpController.text.isEmpty) ...[
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() {
                          _otpController.text = authState.lastGeneratedOtp!;
                          _showAutofillPop = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.ambulanceTeal, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ambulanceTeal.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sms_rounded, size: 18, color: AppColors.ambulanceTeal),
                            const SizedBox(width: 8),
                            Text(
                              'From Messages: Paste OTP (${authState.lastGeneratedOtp})',
                              style: const TextStyle(
                                color: AppColors.ambulanceTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // OTP Input field
              TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                onTap: () {
                  setState(() => _showAutofillPop = true);
                },
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ambulanceTeal,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    letterSpacing: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Paste OTP',
                    icon: const Icon(Icons.content_paste_rounded, color: AppColors.ambulanceTeal, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text?.trim() ?? '';
                      final digits = text.replaceAll(RegExp(r'\D'), '');
                      if (digits.length == 6) {
                        setState(() => _otpController.text = digits);
                      } else if (authState.lastGeneratedOtp != null) {
                        setState(() => _otpController.text = authState.lastGeneratedOtp!);
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                ),
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

              const SizedBox(height: 28),

              // Verify Button
              CustomButton(
                label: 'Verify & Continue',
                icon: Icons.check_circle_rounded,
                isLoading: authState.isLoading,
                onPressed: _handleVerify,
              ),

              const SizedBox(height: 28),

              // Resend OTP Countdown
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in ${_secondsRemaining}s',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _handleResend,
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.ambulanceTeal, size: 18),
                        label: const Text(
                          'Resend Code',
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
