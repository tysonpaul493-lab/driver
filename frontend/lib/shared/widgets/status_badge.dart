import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Styled badge chip for driver verification, booking status, and triage levels
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.fontSize = 12.0,
  });

  /// Factory for Driver verification statuses
  factory StatusBadge.verification(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        return const StatusBadge(
          label: 'VERIFIED',
          backgroundColor: Color(0x2206D6A0),
          textColor: AppColors.verified,
          icon: Icons.check_circle_rounded,
        );
      case 'pending':
      case 'under_review':
        return const StatusBadge(
          label: 'UNDER REVIEW',
          backgroundColor: Color(0x22FF9E00),
          textColor: AppColors.pending,
          icon: Icons.hourglass_top_rounded,
        );
      case 'rejected':
        return const StatusBadge(
          label: 'REJECTED',
          backgroundColor: Color(0x22E63946),
          textColor: AppColors.rejected,
          icon: Icons.cancel_rounded,
        );
      case 'suspended':
      default:
        return const StatusBadge(
          label: 'SUSPENDED',
          backgroundColor: Color(0x226C757D),
          textColor: AppColors.suspended,
          icon: Icons.block_rounded,
        );
    }
  }

  /// Factory for Triage categories
  factory StatusBadge.triage(String category) {
    Color bg;
    Color text;
    IconData icon;

    switch (category.toLowerCase()) {
      case 'critical':
      case 'red':
      case 'trauma':
      case 'cardiac':
        bg = const Color(0x33E63946);
        text = AppColors.triageCritical;
        icon = Icons.emergency_rounded;
        break;
      case 'urgent':
      case 'yellow':
      case 'respiratory':
        bg = const Color(0x33FF9E00);
        text = AppColors.triageUrgent;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        bg = const Color(0x3306D6A0);
        text = AppColors.triageNonUrgent;
        icon = Icons.health_and_safety_rounded;
        break;
    }

    return StatusBadge(
      label: category.toUpperCase(),
      backgroundColor: bg,
      textColor: text,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
