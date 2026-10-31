import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Primary / Emergency action button with loading state, haptic feedback and custom styles
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double height;
  final double fontSize;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.height = 54.0,
    this.fontSize = 16.0,
  });

  /// Critical Emergency Style (Sirens, Accept, Urgent)
  factory CustomButton.emergency({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double height = 56.0,
  }) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon ?? Icons.flash_on_rounded,
      backgroundColor: AppColors.emergencyRed,
      textColor: Colors.white,
      height: height,
      fontSize: 17.0,
    );
  }

  /// Success / Positive Confirmation Style (Arrived, Complete, Call)
  factory CustomButton.success({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double height = 54.0,
  }) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon ?? Icons.check_circle_outline_rounded,
      backgroundColor: AppColors.statusGreen,
      textColor: Colors.black,
      height: height,
      fontSize: 16.0,
    );
  }

  /// Secondary Outlined Style (Decline, Secondary options)
  factory CustomButton.outlined({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    Color? borderColor,
    Color? textColor,
    double height = 52.0,
  }) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: Colors.transparent,
      textColor: textColor ?? AppColors.textPrimary,
      borderColor: borderColor ?? AppColors.borderDark,
      height: height,
      fontSize: 15.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.ambulanceTeal;
    final fg = textColor ?? Colors.black;
    final isOutlined = backgroundColor == Colors.transparent;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: isOutlined ? 0 : 2,
          splashFactory: InkRipple.splashFactory,
          enableFeedback: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined
                ? BorderSide(color: borderColor ?? AppColors.borderDark, width: 1.5)
                : BorderSide.none,
          ),
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: fontSize + 4, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
