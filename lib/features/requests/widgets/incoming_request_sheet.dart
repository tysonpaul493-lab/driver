import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/booking_request_model.dart';
import '../providers/requests_provider.dart';

/// Modal dialog/bottom sheet for incoming emergency ambulance dispatches
class IncomingRequestSheet extends ConsumerStatefulWidget {
  final BookingRequestModel request;

  const IncomingRequestSheet({
    super.key,
    required this.request,
  });

  @override
  ConsumerState<IncomingRequestSheet> createState() => _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends ConsumerState<IncomingRequestSheet>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late final AnimationController _strobeController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.countdownSeconds;
    _strobeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        // Countdown expired: automatically decline so dispatcher routes elsewhere
        ref.read(requestsProvider.notifier).declineRequest(
          widget.request.id,
          reason: 'Countdown expired on driver device',
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _strobeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(requestsProvider);
    final progress = _remainingSeconds / widget.request.countdownSeconds;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.emergencyRed, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top siren strobe header
            Row(
              children: [
                AnimatedBuilder(
                  animation: _strobeController,
                  builder: (context, child) {
                    return Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergencyRed.withValues(alpha: _strobeController.value),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emergencyRed.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                const Text(
                  'NEW EMERGENCY DISPATCH',
                  style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // 2-Minute Countdown timer ring
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.5,
                        backgroundColor: AppColors.borderDark,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds < 20 ? AppColors.emergencyRed : AppColors.alertOrange,
                        ),
                      ),
                      Text(
                        '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Booking Reference & Triage Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.bookingReference,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.request.patientPhone != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppColors.ambulanceTeal),
                          const SizedBox(width: 4),
                          Text(
                            widget.request.patientPhone!,
                            style: const TextStyle(color: AppColors.ambulanceTeal, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                StatusBadge.triage(widget.request.emergencyCategory),
              ],
            ),

            const SizedBox(height: 14),

            // Pickup & Landmark Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.emergencyRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PATIENT PICKUP LOCATION',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.request.pickupAddress,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                        if (widget.request.pickupLandmark != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Landmark: ${widget.request.pickupLandmark!}',
                            style: const TextStyle(color: AppColors.ambulanceTeal, fontSize: 12, height: 1.25),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Distance & ETA Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_filled_rounded, color: AppColors.ambulanceTeal, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DISTANCE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                            const SizedBox(height: 2),
                            Text(
                              '${(widget.request.distanceMeters / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.alertOrange, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ESTIMATED ETA', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                            const SizedBox(height: 2),
                            Text(
                              '~${widget.request.estimatedEtaMinutes} mins',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Essential Assistance Instructions Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.emergencyRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Essential Assistance Instructions:',
                          style: TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.request.essentialInstructions,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (widget.request.destinationHospital != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: AppColors.statusGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Destination: ${widget.request.destinationHospital!}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Accept and Decline Buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomButton.outlined(
                    label: 'Decline',
                    onPressed: () {
                      _timer?.cancel();
                      ref.read(requestsProvider.notifier).declineRequest(
                        widget.request.id,
                        reason: 'Declined by driver',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: CustomButton.emergency(
                    label: 'ACCEPT DISPATCH',
                    isLoading: requestsState.isAccepting,
                    icon: Icons.check_circle_rounded,
                    onPressed: () async {
                      _timer?.cancel();
                      await ref.read(requestsProvider.notifier).acceptRequest(widget.request.id);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
