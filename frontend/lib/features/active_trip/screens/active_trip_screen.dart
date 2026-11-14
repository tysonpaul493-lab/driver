import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
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
  final VoidCallback? onBackToHome;
  const ActiveTripScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  final _handoverNotesController = TextEditingController();
  double? _liveRoadDistanceMeters;

  @override
  void dispose() {
    _handoverNotesController.dispose();
    super.dispose();
  }

  String _formatTripStatusTime(TripModel trip) {
    if (trip.status == TripStatus.completed && trip.completedAt != null) {
      return AppDateUtils.formatTime(trip.completedAt!);
    }
    if (trip.status == TripStatus.patientOnboard && trip.patientPickedUpAt != null) {
      return AppDateUtils.formatTime(trip.patientPickedUpAt!);
    }
    if (trip.status == TripStatus.arrivedAtPickup && trip.arrivedPickupAt != null) {
      return AppDateUtils.formatTime(trip.arrivedPickupAt!);
    }
    return AppDateUtils.formatTime(trip.acceptedAt);
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

  Future<void> _launchExternalNavigation(
    double lat,
    double lng,
    String label,
  ) async {
    final geoUri = Uri.parse(
      'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})',
    );
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    final webRouteUri = Uri.parse(
      'https://www.openstreetmap.org/directions?to=$lat%2C$lng',
    );
    if (await canLaunchUrl(webRouteUri)) {
      await launchUrl(webRouteUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No external navigation app available on this device.'),
        ),
      );
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
            Text(
              'Patient Handover',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm patient handover at ${trip.destinationHospital}.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _handoverNotesController,
              maxLines: 3,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter doctor/nurse handover notes, vital signs, or receiving ward (optional)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notes = _handoverNotesController.text.trim();
              final ok = await ref
                  .read(activeTripProvider.notifier)
                  .advanceWorkflowStep(
                    handoverNotes: notes.isNotEmpty ? notes : null,
                  );
              if (ok && mounted) {
                _handoverNotesController.clear();
                widget.onBackToHome?.call();
              }
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

  void _showPatientChatSheet(TripModel trip) {
    ref.read(activeTripProvider.notifier).markChatRead();
    ref.read(activeTripProvider.notifier).refreshChat();
    final callerLabel = (trip.patientName != null && trip.patientName!.trim().isNotEmpty)
        ? trip.patientName!.trim()
        : ((trip.contactNumber != null && trip.contactNumber!.trim().isNotEmpty)
            ? trip.contactNumber!.trim()
            : trip.bookingReference);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverPatientChatSheet(
        patientName: callerLabel,
        bookingRef: trip.bookingReference,
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
                    color: isCurrent
                        ? AppColors.ambulanceTeal
                        : (isPast ? AppColors.statusGreen : AppColors.cardDark),
                    border: Border.all(color: color),
                  ),
                  child: Center(
                    child: isPast
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${s.stepIndex}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
                if (s != steps.last)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isPast
                          ? AppColors.statusGreen
                          : AppColors.borderDark,
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
      final isCancelled = tripState.cancelledTripRef != null;

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
                        color: (isCancelled ? AppColors.emergencyRed : AppColors.ambulanceTeal).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCancelled ? AppColors.emergencyRed : AppColors.ambulanceTeal,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isCancelled ? AppColors.emergencyRed : AppColors.ambulanceTeal).withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isCancelled ? Icons.cancel_rounded : Icons.emergency_rounded,
                          color: isCancelled ? AppColors.emergencyRed : AppColors.ambulanceTeal,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  isCancelled ? 'Emergency Trip Cancelled' : 'Awaiting Ambulance Booking',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCancelled
                      ? 'The user has cancelled this emergency run (${tripState.cancelledTripRef}). Reason: ${tripState.cancelledReason ?? "User cancelled"}.\nYour vehicle is available for new emergency dispatches.'
                      : 'This trip page only activates when an emergency ride is booked by a patient or hospital and accepted by you.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (isCancelled)
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(activeTripProvider.notifier).dismissCancellation();
                      widget.onBackToHome?.call();
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Return to Home Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ambulanceTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseIndicator(
                        color: onlineState.isOnline
                            ? AppColors.statusGreen
                            : AppColors.alertOrange,
                        size: 8,
                        isPulsing: onlineState.isOnline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        onlineState.isOnline
                            ? 'DISPATCH SYSTEM: ONLINE & LISTENING'
                            : 'DISPATCH SYSTEM: OFFLINE',
                        style: TextStyle(
                          color: onlineState.isOnline
                              ? AppColors.statusGreen
                              : AppColors.alertOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onBackToHome != null) ...[
                  const SizedBox(height: 22),
                  CustomButton(
                    label: 'Back to Dispatch Dashboard',
                    icon: Icons.dashboard_rounded,
                    onPressed: widget.onBackToHome,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final isHeadingToHospital = trip.status.isHeadingToHospital;
    final targetLat = isHeadingToHospital
        ? trip.destinationLatitude
        : trip.pickupLatitude;
    final targetLng = isHeadingToHospital
        ? trip.destinationLongitude
        : trip.pickupLongitude;
    final targetTitle = isHeadingToHospital
        ? trip.destinationHospital
        : trip.pickupAddress;

    final isAtStop = trip.status == TripStatus.arrivedAtPickup ||
        trip.status == TripStatus.arrivedAtHospital ||
        trip.status.isFinished;

    // Calculate phase-aware live road distance (OSRM road meters when available, else Haversine driving estimate)
    double distanceMeters = 0.0;
    if (!isAtStop) {
      if (_liveRoadDistanceMeters != null && _liveRoadDistanceMeters! > 0) {
        distanceMeters = _liveRoadDistanceMeters!;
      } else if (locationState.latitude != null && locationState.longitude != null) {
        distanceMeters = DistanceUtils.calculateDrivingDistanceMeters(
          locationState.latitude!,
          locationState.longitude!,
          targetLat,
          targetLng,
        );
      } else if (trip.distanceRemainingMeters > 0) {
        distanceMeters = trip.distanceRemainingMeters;
      } else {
        distanceMeters = DistanceUtils.calculateDrivingDistanceMeters(
          trip.pickupLatitude,
          trip.pickupLongitude,
          trip.destinationLatitude,
          trip.destinationLongitude,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  trip.bookingReference,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge.triage(trip.emergencyCategory),
              ],
            ),
            Text(
              '${trip.status.displayTitle} • ${_formatTripStatusTime(trip)}',
              style: const TextStyle(
                color: AppColors.ambulanceTeal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
                  color: locationState.isGpsStale
                      ? AppColors.emergencyRed
                      : AppColors.statusGreen,
                  size: 8,
                ),
                const SizedBox(width: 6),
                Text(
                  locationState.isGpsStale ? 'STALE GPS' : 'GPS LOCKED',
                  style: TextStyle(
                    color: locationState.isGpsStale
                        ? AppColors.emergencyRed
                        : AppColors.statusGreen,
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
              currentLng:
                  locationState.longitude ?? trip.pickupLongitude - 0.015,
              heading: locationState.heading,
              targetLat: targetLat,
              targetLng: targetLng,
              targetTitle: targetTitle,
              isHeadingToHospital: isHeadingToHospital,
              accuracy: locationState.accuracy,
              onRouteDistanceUpdated: (meters) {
                if (!mounted) return;
                if (_liveRoadDistanceMeters == null ||
                    (_liveRoadDistanceMeters! - meters).abs() > 20.0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _liveRoadDistanceMeters = meters);
                    }
                  });
                }
              },
              hospitalLat: trip.destinationLatitude,
              hospitalLng: trip.destinationLongitude,
              hospitalName: trip.destinationHospital,
              pickupLat: trip.pickupLatitude,
              pickupLng: trip.pickupLongitude,
              pickupAddress: trip.pickupAddress,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.ambulanceTeal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isHeadingToHospital ? 'TO HOSPITAL' : 'TO PICKUP',
                        style: const TextStyle(
                          color: AppColors.ambulanceTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DistanceUtils.formatDistance(distanceMeters),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  ETA ${DistanceUtils.estimateEta(distanceMeters)}',
                      style: const TextStyle(
                        color: AppColors.alertOrange,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _launchExternalNavigation(
                    targetLat,
                    targetLng,
                    targetTitle,
                  ),
                  style: TextButton.styleFrom(
                    enableFeedback: true,
                    splashFactory: InkRipple.splashFactory,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.turn_right_rounded,
                    size: 18,
                    color: AppColors.ambulanceTeal,
                  ),
                  label: const Text(
                    'NAVIGATE',
                    style: TextStyle(
                      color: AppColors.ambulanceTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient name & Call button
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.ambulanceTeal.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.ambulanceTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (trip.patientName != null && trip.patientName!.trim().isNotEmpty)
                                    ? trip.patientName!
                                    : ((trip.contactNumber != null && trip.contactNumber!.trim().isNotEmpty)
                                        ? trip.contactNumber!
                                        : trip.bookingReference),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_in_talk_rounded,
                                    size: 14,
                                    color: AppColors.ambulanceTeal,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      (trip.contactNumber != null &&
                                              trip.contactNumber!.isNotEmpty)
                                          ? trip.contactNumber!
                                          : 'Patient contact unavailable',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.ambulanceTeal,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showPatientChatSheet(trip),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.ambulanceTeal,
                                    elevation: 0,
                                    minimumSize: const Size(0, 38),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                        color: AppColors.ambulanceTeal,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'CHAT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (tripState.unreadChatCount > 0)
                                  Positioned(
                                    top: -4,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppColors.emergencyRed,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${tripState.unreadChatCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(
                                (trip.contactNumber != null &&
                                        trip.contactNumber!.isNotEmpty)
                                    ? trip.contactNumber
                                    : null,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusGreen,
                                foregroundColor: Colors.white,
                                enableFeedback: true,
                                splashFactory: InkRipple.splashFactory,
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text(
                                'CALL',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 20, color: AppColors.divider),

                    // Destination Hospital (User Booked - Always Visible)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF059669),
                          width: 1.5,
                        ),
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
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DESTINATION HOSPITAL (USER BOOKED)',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip.destinationHospital,
                                  style: const TextStyle(
                                    color: Color(0xFF064E3B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (trip.destinationAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    trip.destinationAddress,
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _launchExternalNavigation(
                              trip.destinationLatitude,
                              trip.destinationLongitude,
                              trip.destinationHospital,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'MAP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Patient Pickup Location
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
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.emergencyRed,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PATIENT PICKUP ADDRESS',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trip.pickupAddress,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (trip.pickupLandmark != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Landmark: ${trip.pickupLandmark!}',
                                    style: const TextStyle(
                                      color: AppColors.ambulanceTeal,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _launchExternalNavigation(
                              trip.pickupLatitude,
                              trip.pickupLongitude,
                              trip.pickupAddress,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.ambulanceTeal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'MAP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Status Checkpoint Timestamps Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled_rounded, size: 15, color: AppColors.ambulanceTeal),
                              const SizedBox(width: 6),
                              Text(
                                'Dispatched: ${AppDateUtils.formatTime(trip.acceptedAt)}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (trip.completedAt != null)
                            Text(
                              'Completed: ${AppDateUtils.formatTime(trip.completedAt!)}',
                              style: const TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (trip.patientPickedUpAt != null)
                            Text(
                              'Onboard: ${AppDateUtils.formatTime(trip.patientPickedUpAt!)}',
                              style: const TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (trip.arrivedPickupAt != null)
                            Text(
                              'Arrived: ${AppDateUtils.formatTime(trip.arrivedPickupAt!)}',
                              style: const TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              trip.status.displayTitle,
                              style: const TextStyle(
                                color: AppColors.ambulanceTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Emergency medical notes box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.emergencyRed.withValues(alpha: 0.3),
                        ),
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Special access instructions
                    if (trip.specialAccessInstructions.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Bottom Action Bar (Always visible & tappable on any phone screen)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: AppColors.borderDark),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: trip.status == TripStatus.arrivedAtHospital
                  ? CustomButton.success(
                      label: trip.status.nextActionLabel,
                      icon: Icons.check_circle_rounded,
                      isLoading: tripState.isLoading,
                      onPressed: () => _showCompleteHandoverDialog(trip),
                    )
                  : CustomButton(
                      label: trip.status.nextActionLabel,
                      icon: Icons.arrow_forward_rounded,
                      isLoading: tripState.isLoading,
                      backgroundColor: isHeadingToHospital
                          ? AppColors.statusGreen
                          : AppColors.ambulanceTeal,
                      textColor: Colors.black,
                      onPressed: () async {
                        await ref
                            .read(activeTripProvider.notifier)
                            .advanceWorkflowStep();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverPatientChatSheet extends ConsumerStatefulWidget {
  final String patientName;
  final String bookingRef;

  const _DriverPatientChatSheet({
    required this.patientName,
    required this.bookingRef,
  });

  @override
  ConsumerState<_DriverPatientChatSheet> createState() =>
      _DriverPatientChatSheetState();
}

class _DriverPatientChatSheetState
    extends ConsumerState<_DriverPatientChatSheet> {
  final _controller = TextEditingController();

  static const _quickReplies = [
    'On the way, sirens active.',
    'Arriving in 2 minutes.',
    'Reached main entrance / gate.',
    'Bringing stretcher now.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    await ref.read(activeTripProvider.notifier).sendChatMessage(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(activeTripProvider);
    final messages = tripState.chatMessages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.ambulanceTeal.withValues(
                  alpha: 0.16,
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: AppColors.ambulanceTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Chat • ${widget.patientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.bookingRef,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.borderDark),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Send quick pickup instructions below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, idx) {
                      final entry = messages[idx];
                      final isDriver = entry['sender']?.toString() == 'driver';
                      final msgText = entry['message']?.toString() ?? '';
                      return Align(
                        alignment: isDriver
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.74,
                          ),
                          decoration: BoxDecoration(
                            color: isDriver
                                ? AppColors.ambulanceTeal
                                : AppColors.cardDark,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            msgText,
                            style: TextStyle(
                              color: isDriver ? Colors.white : AppColors.textPrimary,
                              fontWeight: isDriver
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                backgroundColor: AppColors.cardDark,
                side: const BorderSide(color: AppColors.borderDark),
                label: Text(
                  _quickReplies[i],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _send(_quickReplies[i]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'Message patient / requester...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.ambulanceTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _send(_controller.text),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
