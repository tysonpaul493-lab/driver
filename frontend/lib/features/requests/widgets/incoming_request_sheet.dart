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
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.90,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.emergencyRed, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. FIXED TOP HEADER (Strobe + Timer + Patient Name & Triage) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _strobeController,
                        builder: (context, child) {
                          return Container(
                            width: 12,
                            height: 12,
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
                      const SizedBox(width: 8),
                      const Text(
                        'NEW EMERGENCY DISPATCH',
                        style: TextStyle(
                          color: AppColors.emergencyRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      // Countdown timer ring
                      SizedBox(
                        width: 44,
                        height: 44,
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Patient Name, Booking Ref & Triage Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.patientName ?? 'Emergency Patient',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  widget.request.bookingReference,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.request.patientPhone != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.ambulanceTeal),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.request.patientPhone!,
                                    style: const TextStyle(
                                      color: AppColors.ambulanceTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge.triage(widget.request.emergencyCategory),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderDark, height: 1, thickness: 1),

            // ── 2. SCROLLABLE DETAILS BODY (Cards with spacious, clean padding) ──
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pickup & Landmark Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_rounded, color: AppColors.emergencyRed, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PATIENT PICKUP LOCATION',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.request.pickupAddress,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                if (widget.request.pickupLandmark != null) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.near_me_outlined, size: 12, color: AppColors.ambulanceTeal),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Landmark: ${widget.request.pickupLandmark!}',
                                          style: const TextStyle(
                                            color: AppColors.ambulanceTeal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.ambulanceTeal.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.ambulanceTeal, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DISTANCE',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(widget.request.distanceMeters / 1000).toStringAsFixed(1)} km',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.alertOrange.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.timer_outlined, color: AppColors.alertOrange, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ESTIMATED ETA',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '~${widget.request.estimatedEtaMinutes} mins',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.info_outline_rounded, color: AppColors.emergencyRed, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Essential Assistance Instructions:',
                                  style: TextStyle(
                                    color: AppColors.emergencyRed,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.request.essentialInstructions,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Destination Hospital Card
                    if (widget.request.destinationHospital != null && widget.request.destinationHospital!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF059669), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'USER BOOKED DESTINATION HOSPITAL',
                                    style: TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.request.destinationHospital!,
                                    style: const TextStyle(
                                      color: Color(0xFF064E3B),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (widget.request.destinationAddress != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.request.destinationAddress!,
                                      style: const TextStyle(
                                        color: Color(0xFF047857),
                                        fontSize: 11,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 3. FIXED BOTTOM ACTION BAR (Accept & Decline Buttons - Always 100% visible) ──
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(
                  top: BorderSide(color: AppColors.borderDark, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomButton.outlined(
                      label: 'Decline',
                      height: 48,
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
                      height: 48,
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
            ),
          ],
        ),
      ),
    );
  }
}
