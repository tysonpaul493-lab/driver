import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/distance_utils.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/pulse_indicator.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../location/providers/location_provider.dart';
import '../../navigation/widgets/trip_map_view.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';
import '../providers/active_trip_provider.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final _handoverNotesController = TextEditingController();

  @override
  void dispose() {
    _handoverNotesController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final cleanPhone = phoneNumber.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $phoneNumber')),
        );
      }
    }
  }

  Future<void> _launchExternalNavigation(double lat, double lng, String label) async {
    final googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } else {
      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      }
    }
  }

  void _showCompleteHandoverDialog(TripModel trip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.local_hospital_rounded, color: AppColors.statusGreen),
            SizedBox(width: 10),
            Text('Patient Handover', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm patient handover at ${trip.destinationHospital}.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _handoverNotesController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Enter doctor/nurse handover notes, vital signs, or receiving ward (optional)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notes = _handoverNotesController.text.trim();
              await ref.read(activeTripProvider.notifier).advanceWorkflowStep(
                    handoverNotes: notes.isNotEmpty ? notes : null,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('Complete Trip'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(TripStatus status) {
    final steps = [
      TripStatus.accepted,
      TripStatus.enRouteToPickup,
      TripStatus.arrivedAtPickup,
      TripStatus.patientOnboard,
      TripStatus.inTransitToHospital,
      TripStatus.arrivedAtHospital,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps.map((s) {
          final isPast = status.stepIndex > s.stepIndex;
          final isCurrent = status.stepIndex == s.stepIndex;
          Color color = AppColors.borderDark;
          if (isCurrent) color = AppColors.ambulanceTeal;
          if (isPast) color = AppColors.statusGreen;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? AppColors.ambulanceTeal : (isPast ? AppColors.statusGreen : AppColors.cardDark),
                    border: Border.all(color: color),
                  ),
                  child: Center(
                    child: isPast
                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                        : Text(
                            '${s.stepIndex}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.black : Colors.white,
                            ),
                          ),
                  ),
                ),
                if (s != steps.last)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isPast ? AppColors.statusGreen : AppColors.borderDark,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(activeTripProvider);
    final locationState = ref.watch(driverLocationProvider);

    final trip = tripState.trip;

    if (trip == null || trip.status.isFinished) {
      final onlineState = ref.watch(onlineStatusProvider);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Trip Navigation'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.ambulanceTeal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ambulanceTeal, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ambulanceTeal.withValues(alpha: 0.2),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.emergency_rounded,
                          color: AppColors.ambulanceTeal,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Awaiting Ambulance Booking',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This trip page only activates when an emergency ride is booked by a patient or hospital and accepted by you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseIndicator(
                        color: onlineState.isOnline ? AppColors.statusGreen : AppColors.alertOrange,
                        size: 8,
                        isPulsing: onlineState.isOnline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        onlineState.isOnline
                            ? 'DISPATCH SYSTEM: ONLINE & LISTENING'
                            : 'DISPATCH SYSTEM: OFFLINE',
                        style: TextStyle(
                          color: onlineState.isOnline ? AppColors.statusGreen : AppColors.alertOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isHeadingToHospital = trip.status.isHeadingToHospital;
    final targetLat = isHeadingToHospital ? trip.destinationLatitude : trip.pickupLatitude;
    final targetLng = isHeadingToHospital ? trip.destinationLongitude : trip.pickupLongitude;
    final targetTitle = isHeadingToHospital ? trip.destinationHospital : trip.pickupAddress;

    // Calculate live distance if GPS is available
    double distanceMeters = trip.distanceRemainingMeters;
    if (locationState.latitude != null && locationState.longitude != null) {
      distanceMeters = DistanceUtils.calculateDistanceInMeters(
        locationState.latitude!,
        locationState.longitude!,
        targetLat,
        targetLng,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(trip.bookingReference, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                StatusBadge.triage(trip.emergencyCategory),
              ],
            ),
            Text(
              trip.status.displayTitle,
              style: const TextStyle(color: AppColors.ambulanceTeal, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          // Live GPS Telemetry Indicator
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Row(
              children: [
                PulseIndicator(
                  color: locationState.isGpsStale ? AppColors.emergencyRed : AppColors.statusGreen,
                  size: 8,
                ),
                const SizedBox(width: 6),
                Text(
                  locationState.isGpsStale ? 'STALE GPS' : 'GPS LOCKED',
                  style: TextStyle(
                    color: locationState.isGpsStale ? AppColors.emergencyRed : AppColors.statusGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 7-Step Progress Timeline
          _buildStepIndicator(trip.status),

          // Map View (Enlarged viewport)
          Expanded(
            flex: 4,
            child: TripMapView(
              currentLat: locationState.latitude ?? trip.pickupLatitude - 0.015,
              currentLng: locationState.longitude ?? trip.pickupLongitude - 0.015,
              heading: locationState.heading,
              targetLat: targetLat,
              targetLng: targetLng,
              targetTitle: targetTitle,
              isHeadingToHospital: isHeadingToHospital,
              accuracy: locationState.accuracy,
            ),
          ),

          // Distance and ETA Quick Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.cardDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.navigation_rounded, color: AppColors.ambulanceTeal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DistanceUtils.formatDistance(distanceMeters),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '•   ETA ${DistanceUtils.estimateEta(distanceMeters)}',
                      style: const TextStyle(color: AppColors.alertOrange, fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _launchExternalNavigation(targetLat, targetLng, targetTitle),
                  style: TextButton.styleFrom(
                    enableFeedback: true,
                    splashFactory: InkRipple.splashFactory,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.turn_right_rounded, size: 18, color: AppColors.ambulanceTeal),
                  label: const Text(
                    'NAVIGATE',
                    style: TextStyle(color: AppColors.ambulanceTeal, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Patient & Trip Details Panel (Daylight Theme)
          Expanded(
            flex: 3,
            child: Container(
              color: AppColors.surfaceDark,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient name & Call button
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.ambulanceTeal.withValues(alpha: 0.12),
                          child: const Icon(Icons.person, color: AppColors.ambulanceTeal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.patientName ?? 'Emergency Requester',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.phone_in_talk_rounded, size: 14, color: AppColors.ambulanceTeal),
                                  const SizedBox(width: 4),
                                  Text(
                                    (trip.contactNumber != null && trip.contactNumber!.isNotEmpty)
                                        ? trip.contactNumber!
                                        : '+91 98450 12345',
                                    style: const TextStyle(
                                      color: AppColors.ambulanceTeal,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(
                            (trip.contactNumber != null && trip.contactNumber!.isNotEmpty)
                                ? trip.contactNumber
                                : '+91 98450 12345',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusGreen,
                            foregroundColor: Colors.white,
                            enableFeedback: true,
                            splashFactory: InkRipple.splashFactory,
                            minimumSize: const Size(100, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('CALL', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: AppColors.divider),

                    // Destination Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isHeadingToHospital ? Icons.local_hospital_rounded : Icons.location_on_rounded,
                          color: isHeadingToHospital ? AppColors.statusGreen : AppColors.emergencyRed,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHeadingToHospital ? 'DESTINATION HOSPITAL' : 'PATIENT PICKUP ADDRESS',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                targetTitle,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (!isHeadingToHospital && trip.pickupLandmark != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Landmark: ${trip.pickupLandmark!}',
                                  style: const TextStyle(color: AppColors.ambulanceTeal, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Emergency medical notes box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Medical Emergency Notes:',
                            style: TextStyle(
                              color: AppColors.emergencyRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trip.emergencyNotes,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Special access instructions
                    if (trip.specialAccessInstructions.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Special Access Instructions:',
                              style: TextStyle(
                                color: AppColors.ambulanceTeal,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trip.specialAccessInstructions,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Main Action Step Transition Button
                    if (trip.status == TripStatus.arrivedAtHospital)
                      CustomButton.success(
                        label: trip.status.nextActionLabel,
                        icon: Icons.check_circle_rounded,
                        isLoading: tripState.isLoading,
                        onPressed: () => _showCompleteHandoverDialog(trip),
                      )
                    else
                      CustomButton(
                        label: trip.status.nextActionLabel,
                        icon: Icons.arrow_forward_rounded,
                        isLoading: tripState.isLoading,
                        backgroundColor: isHeadingToHospital ? AppColors.statusGreen : AppColors.ambulanceTeal,
                        textColor: Colors.black,
                        onPressed: () async {
                          await ref.read(activeTripProvider.notifier).advanceWorkflowStep();
                        },
                      ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
