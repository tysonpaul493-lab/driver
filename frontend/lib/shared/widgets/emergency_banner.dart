import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Alert banner displayed at the top of screens for warnings or critical system notices
class EmergencyBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  const EmergencyBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.backgroundColor = const Color(0x33FF9E00),
    this.borderColor = AppColors.alertOrange,
    this.textColor = AppColors.textPrimary,
    this.onActionTap,
    this.actionLabel,
  });

  factory EmergencyBanner.verificationPending({VoidCallback? onRefresh}) {
    return EmergencyBanner(
      title: 'Verification In Progress',
      message: 'Your documents and vehicle permit are undergoing administrative review. You will be able to go online once approved.',
      icon: Icons.shield_outlined,
      backgroundColor: const Color(0x22FF9E00),
      borderColor: AppColors.alertOrange,
      actionLabel: 'Check Status',
      onActionTap: onRefresh,
    );
  }

  factory EmergencyBanner.offlineNotice({VoidCallback? onGoOnline}) {
    return EmergencyBanner(
      title: 'You are Currently Offline',
      message: 'Switch to Online to start receiving emergency ambulance dispatches in your area.',
      icon: Icons.cloud_off_rounded,
      backgroundColor: const Color(0x221B2A4A),
      borderColor: AppColors.borderDark,
      actionLabel: 'Go Online',
      onActionTap: onGoOnline,
    );
  }

  factory EmergencyBanner.gpsWarning({VoidCallback? onGrant}) {
    return EmergencyBanner(
      title: 'GPS Signal Degraded / Disabled',
      message: 'High-accuracy location is required to receive assignments and navigate to emergency patients.',
      icon: Icons.gps_off_rounded,
      backgroundColor: const Color(0x33E63946),
      borderColor: AppColors.emergencyRed,
      actionLabel: 'Enable GPS',
      onActionTap: onGrant,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onActionTap,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: borderColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
