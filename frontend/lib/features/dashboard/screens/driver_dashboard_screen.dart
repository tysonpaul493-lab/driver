import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/constants/app_colors.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../../../shared/widgets/cartographic_map_background.dart';
import '../../../shared/widgets/emergency_banner.dart';
import '../../../shared/widgets/pulse_indicator.dart';
import '../../active_trip/providers/active_trip_provider.dart';
import '../../active_trip/screens/active_trip_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/screens/trip_history_screen.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/driver_profile_screen.dart';
import '../../requests/providers/requests_provider.dart';
import '../../requests/widgets/incoming_request_sheet.dart';
import '../providers/dashboard_provider.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen>
    with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  final MapController _mapController = MapController();
  bool _isRequestSheetOpen = false;
  bool _hasCenteredMapOnGps = false;
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(onlineStatusProvider.notifier)
          .syncWithAuthenticatedDriver();
      await ref.read(activeTripProvider.notifier).checkActiveTrip();
      await ref.read(driverLocationProvider.notifier).refreshCurrentLocation();
      if (!ref.read(activeTripProvider).hasActiveTrip &&
          ref.read(onlineStatusProvider).isOnline) {
        await ref.read(driverLocationProvider.notifier).startTracking();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapRotationNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(reverbServiceProvider).reconnectIfActive();
      ref.read(onlineStatusProvider.notifier).syncWithAuthenticatedDriver();
      ref.read(activeTripProvider.notifier).checkActiveTrip();
      ref.read(driverLocationProvider.notifier).refreshCurrentLocation();
    }
  }

  void _listenToIncomingRequests(BuildContext context) {
    ref.listen<RequestsState>(requestsProvider, (prev, next) {
      // 1. New incoming booking dispatch modal
      if (next.currentIncomingRequest != null &&
          prev?.currentIncomingRequest == null &&
          !_isRequestSheetOpen) {
        _isRequestSheetOpen = true;
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              IncomingRequestSheet(request: next.currentIncomingRequest!),
        ).whenComplete(() {
          _isRequestSheetOpen = false;
        });
      } else if (next.currentIncomingRequest == null &&
          prev?.currentIncomingRequest != null) {
        // Automatically pop modal if request was claimed by another or cancelled
        if (_isRequestSheetOpen && Navigator.of(context).canPop()) {
          _isRequestSheetOpen = false;
          Navigator.of(context).pop();
        }
      }

      // 2. Race condition conflict dialog
      if (next.conflictMessage != null &&
          prev?.conflictMessage != next.conflictMessage) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.info_rounded, color: AppColors.alertOrange),
                SizedBox(width: 8),
                Text(
                  'Booking Unavailable',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              next.conflictMessage!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(requestsProvider.notifier).dismissConflictMessage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ambulanceTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    // Listen to trip accepted transition or cancellation: jump straight to Active Trip screen or return to Home
    ref.listen<ActiveTripState>(activeTripProvider, (prev, next) {
      if (next.hasActiveTrip && (prev == null || !prev.hasActiveTrip)) {
        setState(() => _currentTabIndex = 1);
      } else if (next.cancelledTripRef != null &&
          prev?.cancelledTripRef != next.cancelledTripRef) {
        // Trip was cancelled by user: stop navigation & show alert modal
        setState(() => _currentTabIndex = 0);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.cancel_rounded,
                  color: AppColors.emergencyRed,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trip Cancelled by User',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'The requester has cancelled emergency ride ${next.cancelledTripRef}.\n\nReason: ${next.cancelledReason ?? "Cancelled by user"}\n\nYour ambulance has been set back to available status.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(activeTripProvider.notifier).dismissCancellation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ambulanceTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    });

    // Animate map camera on initial GPS fix without hijacking user zoom/pan on every telemetry tick
    ref.listen<DriverLocationState>(driverLocationProvider, (prev, next) {
      if (!_hasCenteredMapOnGps &&
          next.latitude != null &&
          next.longitude != null &&
          next.latitude != 0.0 &&
          next.longitude != 0.0) {
        _hasCenteredMapOnGps = true;
        try {
          _mapController.move(ll.LatLng(next.latitude!, next.longitude!), 15.0);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenToIncomingRequests(context);
    final requests = ref.watch(requestsProvider);

    final pages = [
      _buildHomeDashboardTab(),
      ActiveTripScreen(
        onBackToHome: () => setState(() => _currentTabIndex = 0),
      ),
      const TripHistoryScreen(),
      const NotificationsScreen(),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentTabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.ambulanceTeal.withValues(alpha: 0.2),
        onDestinationSelected: (idx) {
          setState(() => _currentTabIndex = idx);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: AppColors.ambulanceTeal,
            ),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(
              Icons.navigation_outlined,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.navigation_rounded,
              color: AppColors.ambulanceTeal,
            ),
            label: 'Trip',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_rounded, color: AppColors.textSecondary),
            selectedIcon: Icon(
              Icons.history_toggle_off_rounded,
              color: AppColors.ambulanceTeal,
            ),
            label: 'History',
          ),
          NavigationDestination(
            icon: requests.pendingRequests.isNotEmpty
                ? Badge.count(
                    count: requests.pendingRequests.length,
                    backgroundColor: AppColors.alertOrange,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textSecondary,
                    ),
                  )
                : const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textSecondary,
                  ),
            selectedIcon: requests.pendingRequests.isNotEmpty
                ? Badge.count(
                    count: requests.pendingRequests.length,
                    backgroundColor: AppColors.alertOrange,
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.ambulanceTeal,
                    ),
                  )
                : const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.ambulanceTeal,
                  ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
              color: AppColors.textSecondary,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.ambulanceTeal,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboardTab() {
    debugPrint('[Dashboard] _buildHomeDashboardTab called');
    final driver = ref.watch(currentDriverProvider);
    final vehicle = driver?.assignedVehicle;
    final onlineState = ref.watch(onlineStatusProvider);
    final locationState = ref.watch(driverLocationProvider);
    final tripState = ref.watch(activeTripProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final requestsState = ref.watch(requestsProvider);
    debugPrint(
      '[Dashboard] driver=${driver?.name}, vehicle=${vehicle?.registrationNumber}, online=${onlineState.isOnline}',
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ambulanceTeal, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          driver?.name.trim().isNotEmpty == true
                              ? driver!.name
                              : (driver?.phone.trim().isNotEmpty == true
                                    ? driver!.phone
                                    : 'Complete Profile'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.statusGreen,
                        size: 16,
                      ),
                    ],
                  ),
                  Text(
                    vehicle?.registrationNumber.isNotEmpty == true
                        ? vehicle!.registrationNumber
                        : 'No Plate Registered',
                    style: const TextStyle(
                      color: AppColors.ambulanceTeal,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseIndicator(
                color: onlineState.isOnline
                    ? AppColors.statusGreen
                    : AppColors.textMuted,
                size: 8,
                isPulsing: onlineState.isOnline,
              ),
              const SizedBox(width: 4),
              Text(
                onlineState.isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: onlineState.isOnline
                      ? AppColors.statusGreen
                      : AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: onlineState.isOnline,
                  activeThumbColor: AppColors.statusGreen,
                  onChanged: onlineState.isLoading
                      ? null
                      : (val) async {
                          final success = await ref
                              .read(onlineStatusProvider.notifier)
                              .toggleOnline(val);
                          if (!success && mounted) {
                            final err = ref
                                .read(onlineStatusProvider)
                                .errorMessage;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.emergencyRed,
                                  content: Text(
                                    err,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.ambulanceTeal,
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          await ref
              .read(authNotifierProvider.notifier)
              .refreshVerificationStatus();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. EMERGENCY BOOKING DISPATCH NOTIFICATION BAR (2-MINUTE COUNTDOWN)
              if (requestsState.currentIncomingRequest != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE63946), Color(0xFF9E0B0F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emergencyRed.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      PulseIndicator(
                        color: Colors.white,
                        size: 14,
                        isPulsing: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '🚨 NEW EMERGENCY DISPATCH',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${((requestsState.currentIncomingRequest?.countdownSeconds ?? 120) ~/ 60).toString().padLeft(2, '0')}:${((requestsState.currentIncomingRequest?.countdownSeconds ?? 120) % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Patient: ${requestsState.currentIncomingRequest!.patientName} • ${requestsState.currentIncomingRequest!.emergencyCategory}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              requestsState
                                  .currentIncomingRequest!
                                  .pickupAddress,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _isRequestSheetOpen = true;
                          showModalBottomSheet(
                            context: context,
                            isDismissible: false,
                            enableDrag: false,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => IncomingRequestSheet(
                              request: requestsState.currentIncomingRequest!,
                            ),
                          ).whenComplete(() {
                            _isRequestSheetOpen = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.emergencyRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'RESPOND',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Error banner if any
              if (onlineState.errorMessage != null) ...[
                const SizedBox(height: 10),
                EmergencyBanner(
                  title: 'Unable to Go Online',
                  message: onlineState.errorMessage!,
                  icon: Icons.error_outline_rounded,
                  backgroundColor: const Color(0x33E63946),
                  borderColor: AppColors.emergencyRed,
                ),
              ],

              // 1.5 PENDING DISPATCH REQUESTS BANNER
              if (requestsState.pendingRequests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFB703),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.alertOrange,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const PulseIndicator(
                        color: AppColors.alertOrange,
                        size: 12,
                        isPulsing: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${requestsState.pendingRequests.length} PENDING EMERGENCY REQUEST(S)',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to review patient details and accept dispatch',
                              style: TextStyle(
                                color: AppColors.alertOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final req =
                              requestsState.currentIncomingRequest ??
                              requestsState.pendingRequests.first;
                          showModalBottomSheet(
                            context: context,
                            isDismissible: false,
                            enableDrag: false,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => IncomingRequestSheet(request: req),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.alertOrange,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(76, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'RESPOND',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. ACTIVE TRIP ALERT BANNER
              if (tripState.hasActiveTrip) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x3300E5FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.ambulanceTeal,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emergency_rounded,
                        color: AppColors.ambulanceTeal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRIP IN PROGRESS: ${tripState.trip!.bookingReference}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tripState.trip!.status.displayTitle,
                              style: const TextStyle(
                                color: AppColors.ambulanceTeal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => _currentTabIndex = 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ambulanceTeal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 36),
                        ),
                        child: const Text('RESUME'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 3. DRIVER LIVE LOCATION CARD & REAL-TIME MAP
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          PulseIndicator(
                            color: AppColors.statusGreen,
                            size: 10,
                            isPulsing: true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DRIVER LIVE DISPATCH LOCATION',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: AppColors.ambulanceTeal,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationState.currentAddress.isNotEmpty
                                            ? locationState.currentAddress
                                            : 'Resolving live street address...',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 20,
                              color: AppColors.ambulanceTeal,
                            ),
                            tooltip: 'Refresh GPS Fix',
                            onPressed: () async {
                              await ref
                                  .read(driverLocationProvider.notifier)
                                  .refreshCurrentLocation();
                              final loc = ref.read(driverLocationProvider);
                              if (loc.latitude != null &&
                                  loc.longitude != null) {
                                try {
                                  _mapController.move(
                                    ll.LatLng(loc.latitude!, loc.longitude!),
                                    15.5,
                                  );
                                } catch (_) {}
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Live Interactive Mini Map Canvas (Daylight navigation)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                      child: RepaintBoundary(
                        child: SizedBox(
                          height: 520,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              // Rich cartographic base canvas
                              const Positioned.fill(
                                child: CartographicMapBackground(),
                              ),

                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: ll.LatLng(
                                    locationState.latitude ?? 12.9716,
                                    locationState.longitude ?? 77.5946,
                                  ),
                                  initialZoom: 15.5,
                                  initialRotation: _mapRotationNotifier.value,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all,
                                    enableMultiFingerGestureRace: false,
                                    rotationThreshold: 8.0,
                                    pinchZoomThreshold: 0.15,
                                    pinchMoveThreshold: 15.0,
                                  ),
                                  onPositionChanged: (camera, hasGesture) {
                                    if ((_mapRotationNotifier.value - camera.rotation).abs() > 0.2) {
                                      _mapRotationNotifier.value = camera.rotation;
                                    }
                                  },
                                ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.liferoute.driver',
                                  maxZoom: 19,
                                  fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                ),
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: ll.LatLng(
                                        locationState.latitude ?? 12.9716,
                                        locationState.longitude ?? 77.5946,
                                      ),
                                      radius: locationState.accuracy.clamp(
                                        12.0,
                                        45.0,
                                      ),
                                      useRadiusInMeter: false,
                                      color: const Color(0x224285F4),
                                      borderColor: const Color(0xFF4285F4),
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: ll.LatLng(
                                        locationState.latitude ?? 12.9716,
                                        locationState.longitude ?? 77.5946,
                                      ),
                                      width: 68,
                                      height: 68,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Pulsing halo ring
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0x334285F4),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          // Core Google Maps navigation puck
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFF1A73E8),
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF1A73E8)
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Transform.rotate(
                                                angle:
                                                    (locationState.heading *
                                                    math.pi /
                                                    180),
                                                child: const Icon(
                                                  Icons.navigation_rounded,
                                                  color: Color(0xFF1A73E8),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Clean In-App Map Attribution Banner (Bottom-Left)
                            Positioned(
                              bottom: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.navigation_rounded,
                                      size: 12,
                                      color: AppColors.ambulanceTeal,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'LifeRoute Live Map',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Map Zoom & Recenter & Compass Controls Overlay
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Column(
                                children: [
                                  // Compass / Reset North Button (Smooth Rotation via ValueNotifier)
                                  Material(
                                    color: AppColors.surfaceDark.withValues(
                                      alpha: 0.9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: AppColors.borderDark,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        try {
                                          _mapController.rotate(0.0);
                                          _mapRotationNotifier.value = 0.0;
                                        } catch (_) {}
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: ValueListenableBuilder<double>(
                                          valueListenable: _mapRotationNotifier,
                                          builder: (context, rotation, child) {
                                            return Transform.rotate(
                                              angle: -(rotation * math.pi / 180.0),
                                              child: const Icon(
                                                Icons.explore_rounded,
                                                color: AppColors.ambulanceTeal,
                                                size: 20,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Recenter / My Location Button
                                  Material(
                                    color: AppColors.surfaceDark.withValues(
                                      alpha: 0.9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: AppColors.borderDark,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        if (locationState.latitude != null &&
                                            locationState.longitude != null) {
                                          _mapController.move(
                                            ll.LatLng(
                                              locationState.latitude!,
                                              locationState.longitude!,
                                            ),
                                            15.5,
                                          );
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.my_location_rounded,
                                          color: AppColors.ambulanceTeal,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    setState(() => _currentTabIndex = 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.ambulanceTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.fullscreen_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Open Trip Map',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. COMPACT SHIFT METRICS (MINIMIZED 4 BOXES IN A SINGLE ROW)
              const Text(
                'Today’s Operational Summary',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              summaryAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.ambulanceTeal,
                  ),
                ),
                error: (e, s) => const SizedBox(),
                data: (summary) => Row(
                  children: [
                    Expanded(
                      child: _buildCompactMetric(
                        'Trips',
                        '${summary.completedTripsToday}',
                        Icons.check_circle_rounded,
                        AppColors.statusGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactMetric(
                        'Distance',
                        '${summary.distanceCoveredKm.toStringAsFixed(1)}km',
                        Icons.route_rounded,
                        AppColors.ambulanceTeal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactMetric(
                        'Online',
                        '${summary.onlineHours.toStringAsFixed(1)}h',
                        Icons.access_time_rounded,
                        AppColors.alertOrange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactMetric(
                        'Critical',
                        '${summary.emergencyCriticalTrips}',
                        Icons.emergency_rounded,
                        AppColors.emergencyRed,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. ASSIGNED AMBULANCE PREVIEW (Registered details)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.airport_shuttle_rounded,
                        color: AppColors.ambulanceTeal,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle?.registrationNumber.isNotEmpty == true
                                ? vehicle!.registrationNumber
                                : 'No Plate Registered',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle?.makeModel.isNotEmpty == true ? vehicle!.makeModel : "Ambulance"} • ${vehicle?.vehicleType.displayName ?? "BLS"}${vehicle?.operatorAffiliation.isNotEmpty == true ? " • ${vehicle!.operatorAffiliation}" : ""}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 15,
                      ),
                      onPressed: () => setState(() => _currentTabIndex = 4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 14),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
