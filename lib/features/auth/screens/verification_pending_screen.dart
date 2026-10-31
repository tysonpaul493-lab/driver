import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../dashboard/screens/driver_dashboard_screen.dart';
import '../../profile/screens/driver_profile_screen.dart';
import '../models/driver_model.dart';
import '../providers/auth_provider.dart';
import 'document_upload_screen.dart';

class VerificationPendingScreen extends ConsumerStatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  ConsumerState<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends ConsumerState<VerificationPendingScreen> {
  bool _isRefreshing = false;

  Future<void> _checkStatus() async {
    setState(() => _isRefreshing = true);
    await ref.read(authNotifierProvider.notifier).refreshVerificationStatus();
    setState(() => _isRefreshing = false);

    final driver = ref.read(currentDriverProvider);
    if (driver?.verificationStatus.isApproved ?? false) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              'Status: ${driver?.verificationStatus.displayName ?? "Under Review"}. Dispatch admins are reviewing your credentials.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  Future<void> _callDispatchSupport() async {
    final uri = Uri.parse('tel:108');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);
    final status = driver?.verificationStatus ?? VerificationStatus.underReview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Verification Status'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppColors.ambulanceTeal),
            tooltip: 'Driver Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Status Icon Container
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: status.isRejected ? AppColors.emergencyRed : AppColors.alertOrange,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    status.isRejected ? Icons.highlight_off_rounded : Icons.hourglass_top_rounded,
                    color: status.isRejected ? AppColors.emergencyRed : AppColors.alertOrange,
                    size: 44,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              StatusBadge.verification(status.name),
              const SizedBox(height: 16),

              Text(
                status.isRejected
                    ? 'Registration Requires Attention'
                    : 'Administrative Audit in Progress',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                status.isRejected
                    ? (driver?.rejectionReason ??
                        'One or more submitted documents or vehicle permits did not pass emergency compliance criteria. Please re-upload valid documents.')
                    : 'Your driving licence, vehicle registration, and ambulance equipment compliance are being reviewed by emergency control administrators.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 28),

              // Driver & Vehicle Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: AppColors.ambulanceTeal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          driver?.name ?? 'Ambulance Pilot',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.divider),
                    _buildInfoRow('Licence Number:', driver?.licenseNumber ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Ambulance Plate:',
                      driver?.assignedVehicle?.registrationNumber ?? 'AMB-PENDING',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Vehicle Class:',
                      driver?.assignedVehicle?.vehicleType.displayName ?? 'ALS Ambulance',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Operator / Fleet:',
                      driver?.assignedVehicle?.operatorAffiliation ?? 'Regional Dispatch',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              CustomButton(
                label: 'Check Verification Status',
                icon: Icons.refresh_rounded,
                isLoading: _isRefreshing,
                onPressed: _checkStatus,
              ),

              const SizedBox(height: 14),

              CustomButton.outlined(
                label: 'Update Submitted Documents',
                icon: Icons.upload_file_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentUploadScreen()),
                  );
                },
              ),

              const SizedBox(height: 14),

              CustomButton.outlined(
                label: 'Call Dispatch Support',
                icon: Icons.phone_in_talk_rounded,
                borderColor: AppColors.emergencyRed.withValues(alpha: 0.5),
                textColor: AppColors.emergencyRed,
                onPressed: _callDispatchSupport,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
