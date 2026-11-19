import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/server_settings_dialog.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/screens/driver_dashboard_screen.dart';
import 'driver_registration_screen.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  const PhoneLoginScreen({super.key, this.initialPhone});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCountryCode = '+91';
  bool _obscurePassword = true;

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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final fullPhone = PhoneUtils.buildInternationalPhone(
      _selectedCountryCode,
      _phoneController.text,
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .loginWithPassword(
          phone: fullPhone,
          password: _passwordController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      FocusScope.of(context).unfocus();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
        (route) => false,
      );
    } else {
      final rawErr = ref.read(authNotifierProvider).errorMessage ??
          'Invalid mobile number or password. Please try again.';
      final err = (rawErr.contains('minified') ||
              rawErr.contains('subtype') ||
              rawErr.contains('TypeError') ||
              rawErr.contains('Instance of'))
          ? 'Invalid mobile number or password. Please verify your credentials and try again.'
          : rawErr;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.emergencyRed,
          action: SnackBarAction(
            label: 'Server IP',
            textColor: Colors.white,
            onPressed: () => showDriverServerSettingsDialog(context, ref),
          ),
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final resetPhoneController = TextEditingController(text: _phoneController.text);
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isResetting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reset Password',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your registered mobile number and create a new password.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: resetPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Registered Mobile Number *',
                        prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textSecondary),
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7 || digits.length > 15) {
                          return 'Enter valid registered mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'New Password *',
                        hintText: 'Minimum 6 characters',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password *',
                        hintText: 'Re-enter new password',
                        prefixIcon: const Icon(Icons.lock_clock_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != newPassController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Save Password & Sign In',
                      icon: Icons.check_circle_rounded,
                      isLoading: isResetting,
                      onPressed: isResetting
                          ? null
                          : () async {
                              if (!resetFormKey.currentState!.validate()) return;
                              setSheetState(() => isResetting = true);
                              final fullPhone = PhoneUtils.buildInternationalPhone(
                                _selectedCountryCode,
                                resetPhoneController.text,
                              );
                              final ok = await ref.read(authNotifierProvider.notifier).resetPassword(
                                    phone: fullPhone,
                                    newPassword: newPassController.text.trim(),
                                    confirmPassword: confirmPassController.text.trim(),
                                  );
                              setSheetState(() => isResetting = false);
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password reset successfully! Logged in.'),
                                    backgroundColor: AppColors.ambulanceTeal,
                                  ),
                                );
                              } else {
                                final err = ref.read(authNotifierProvider).errorMessage ??
                                    'Failed to reset password. Please check your mobile number.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: AppColors.emergencyRed,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                // Trust Official Logo Brand Badge
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ambulanceTeal, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ambulanceTeal.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ஆல் இந்தியா தமிழ் அனைத்து அறக்கட்டளை',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'தமிழ்நாடு அவசர ஊர்தி ஓட்டுநர் கன்சோல்',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ambulanceTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
                  'Enter your registered mobile number and password to sign in.',
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
                          final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.isEmpty) {
                            return 'Enter phone number';
                          }
                          if (digits.length < 7 || digits.length > 15) {
                            return 'Enter valid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Password Input Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter password';
                    }
                    if (value.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ambulanceTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 8),
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
                            (authState.errorMessage!.contains('minified') ||
                                    authState.errorMessage!.contains('subtype') ||
                                    authState.errorMessage!.contains('TypeError') ||
                                    authState.errorMessage!.contains('Instance of'))
                                ? 'Invalid mobile number or password. Please verify your credentials and try again.'
                                : authState.errorMessage!,
                            style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Password Sign In Button
                CustomButton(
                  label: 'Sign In',
                  icon: Icons.login_rounded,
                  isLoading: authState.isLoading,
                  onPressed: _handlePasswordLogin,
                ),

                const SizedBox(height: 16),

                // New Driver Registration Entry
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DriverRegistrationScreen(
                                  initialPhone: _phoneController.text.trim(),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.app_registration_rounded, size: 20),
                    label: const Text(
                      'New Driver? Register Driver & Ambulance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ambulanceTeal,
                      side: const BorderSide(color: AppColors.ambulanceTeal, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showDriverServerSettingsDialog(context, ref),
                    icon: const Icon(Icons.tune_rounded, size: 14, color: AppColors.textMuted),
                    label: const Text(
                      'Emergency Dispatch Server Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
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
