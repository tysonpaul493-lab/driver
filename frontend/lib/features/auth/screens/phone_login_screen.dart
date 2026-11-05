import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import 'driver_registration_screen.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  const PhoneLoginScreen({super.key, this.initialPhone});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCountryCode = '+91';

  @override
  void initState() {
    super.initState();

    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      final clean = widget.initialPhone!.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10) {
        _phoneController.text = clean.substring(clean.length - 10);
      } else {
        _phoneController.text = clean;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final fullPhone = '$_selectedCountryCode${_phoneController.text.trim()}';

    // Verify if registered as a driver
    final isRegistered = await ref.read(authNotifierProvider.notifier).isPhoneRegistered(fullPhone);
    if (!isRegistered) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.alertOrange, size: 26),
                SizedBox(width: 8),
                Text(
                  'Driver Not Registered',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Mobile number $fullPhone is not registered as an emergency ambulance driver. You must complete driver registration first to receive OTP.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()),
                  );
                },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Register Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ambulanceTeal,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).sendOtp(fullPhone);
    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phoneNumber: fullPhone),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Ambulance Pilot Badge Icon
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ambulanceTeal, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ambulanceTeal.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: AppColors.ambulanceTeal,
                        size: 46,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Center(
                  child: Text(
                    'LifeRoute Driver',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Emergency Ambulance Dispatch System',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Driver Sign In',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your registered mobile number to receive a 6-digit secure login OTP.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Phone Input Field
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          dropdownColor: AppColors.cardDark,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(value: '+91', child: Text('+91 (IN)')),
                            DropdownMenuItem(value: '+1', child: Text('+1 (US)')),
                            DropdownMenuItem(value: '+44', child: Text('+44 (UK)')),
                            DropdownMenuItem(value: '+61', child: Text('+61 (AU)')),
                            DropdownMenuItem(value: '+971', child: Text('+971 (AE)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCountryCode = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter Mobile Number',
                          prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          if (value.trim().length < 7) {
                            return 'Enter valid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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

                // Send OTP Button
                CustomButton(
                  label: 'Request OTP',
                  icon: Icons.send_rounded,
                  isLoading: authState.isLoading,
                  onPressed: _handleSendOtp,
                ),

                const SizedBox(height: 36),

                // Register Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New ambulance driver or fleet? ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DriverRegistrationScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              'Register Here',
                              style: TextStyle(
                                color: AppColors.ambulanceTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
