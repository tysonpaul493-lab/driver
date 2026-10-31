import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/audio_alert_service.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../history/screens/trip_history_screen.dart';
import '../../location/providers/location_provider.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';
import '../repositories/active_trip_repository.dart';

final activeTripRepositoryProvider = Provider<ActiveTripRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return ActiveTripRepository(dio, storage);
});

class ActiveTripState {
  final TripModel? trip;
  final bool isLoading;
  final String? errorMessage;
  final String? lastActionMessage;

  const ActiveTripState({
    this.trip,
    this.isLoading = false,
    this.errorMessage,
    this.lastActionMessage,
  });

  bool get hasActiveTrip => trip != null && !trip!.status.isFinished;

  ActiveTripState copyWith({
    TripModel? trip,
    bool? isLoading,
    String? errorMessage,
    String? lastActionMessage,
    bool clearTrip = false,
  }) {
    return ActiveTripState(
      trip: clearTrip ? null : (trip ?? this.trip),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
    );
  }
}

class ActiveTripNotifier extends StateNotifier<ActiveTripState> {
  final ActiveTripRepository _repository;
  final Ref _ref;
  StreamSubscription? _reverbCancellationSub;
  StreamSubscription? _reverbDestinationSub;

  ActiveTripNotifier(this._repository, this._ref) : super(const ActiveTripState()) {
    checkActiveTrip();
  }

  /// Check if there is an in-flight trip (e.g. app restart or crash recovery)
  Future<void> checkActiveTrip() async {
    state = state.copyWith(isLoading: true);
    try {
      final trip = await _repository.getActiveTrip();
      if (trip != null && !trip.status.isFinished) {
        state = state.copyWith(trip: trip, isLoading: false);
        _subscribeToTripEvents(trip.id);
        // Ensure location tracking is active for this trip
        _ref.read(driverLocationProvider.notifier).startTracking(
          bookingReference: trip.bookingReference,
        );
      } else {
        state = state.copyWith(isLoading: false, clearTrip: true);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Set trip right after accepting a dispatch request
  void setTrip(TripModel trip) {
    state = state.copyWith(trip: trip, isLoading: false);
    _subscribeToTripEvents(trip.id);
    _ref.read(driverLocationProvider.notifier).startTracking(
      bookingReference: trip.bookingReference,
    );
  }

  /// Advance to the next workflow step in the strict 7-step state machine
  Future<bool> advanceWorkflowStep({String? handoverNotes}) async {
    final currentTrip = state.trip;
    if (currentTrip == null) return false;

    final next = currentTrip.status.nextStatus;
    if (next == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final location = _ref.read(driverLocationProvider);
      final updatedTrip = await _repository.updateTripStatus(
        tripId: currentTrip.id,
        newStatus: next,
        latitude: location.latitude,
        longitude: location.longitude,
        handoverNotes: handoverNotes,
      );

      await AudioAlertService.playActionConfirmed();

      if (next.isFinished) {
        // Complete trip: save to local history, stop live GPS tracking and unsubscribe channels
        final storage = _ref.read(storageServiceProvider);
        await storage.saveCompletedTrip(updatedTrip.toJson());
        await _ref.read(driverLocationProvider.notifier).stopTracking();
        await _ref.read(reverbServiceProvider).unsubscribeBookingChannel();

        // Dynamically refresh Today's Operational Summary metrics & Trip History
        _ref.invalidate(dashboardSummaryProvider);
        _ref.invalidate(tripHistoryProvider);

        state = state.copyWith(
          trip: updatedTrip,
          isLoading: false,
          lastActionMessage: 'Emergency trip successfully completed.',
        );
      } else {
        state = state.copyWith(
          trip: updatedTrip,
          isLoading: false,
          lastActionMessage: 'Step updated to: ${next.displayTitle}',
        );
      }
      return true;
    } catch (_) {
      // Offline fallback: update local trip model so dispatch workflow is never blocked
      final updated = currentTrip.copyWith(
        status: next,
        handoverNotes: handoverNotes ?? currentTrip.handoverNotes,
      );
      await AudioAlertService.playActionConfirmed();
      if (next.isFinished) {
        final storage = _ref.read(storageServiceProvider);
        await storage.saveCompletedTrip(updated.toJson());
        await _ref.read(driverLocationProvider.notifier).stopTracking();
        try {
          await _ref.read(reverbServiceProvider).unsubscribeBookingChannel();
        } catch (_) {}

        _ref.invalidate(dashboardSummaryProvider);
        _ref.invalidate(tripHistoryProvider);
      }
      state = state.copyWith(
        trip: updated,
        isLoading: false,
        lastActionMessage: 'Step updated to: ${next.displayTitle}',
      );
      return true;
    }
  }

  /// Start a fully functional demo emergency dispatch trip
  void startDemoTrip() {
    final location = _ref.read(driverLocationProvider);
    final currentLat = location.latitude ?? 12.9716;
    final currentLng = location.longitude ?? 77.5946;
    final demoTrip = TripModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      bookingReference: 'BK-${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}',
      status: TripStatus.accepted,
      pickupAddress: 'Emergency Pickup Location, Bengaluru',
      pickupLandmark: 'Opposite Metro Station Pillar #142',
      pickupLatitude: currentLat + 0.008,
      pickupLongitude: currentLng + 0.007,
      destinationHospital: 'Apollo Emergency & Trauma Centre',
      destinationAddress: 'Bannerghatta Main Road, Bengaluru',
      destinationLatitude: currentLat + 0.018,
      destinationLongitude: currentLng + 0.015,
      emergencyCategory: 'Critical',
      emergencyNotes: 'Severe road injury. Oxygen & vital monitoring required.',
      specialAccessInstructions: 'Enter via Emergency Ambulance Bay #1.',
      patientName: 'Ramesh Patel (Critical Trauma)',
      contactNumber: '+91 98450 12345',
      distanceRemainingMeters: 4800,
      acceptedAt: DateTime.now(),
    );
    setTrip(demoTrip);
    _ref.read(driverLocationProvider.notifier).startTracking(
          bookingReference: demoTrip.bookingReference,
        );
  }

  void _subscribeToTripEvents(int tripId) {
    final reverb = _ref.read(reverbServiceProvider);
    reverb.subscribeToBookingChannel(tripId);

    _reverbCancellationSub?.cancel();
    _reverbCancellationSub = reverb.onBookingCancelled.listen((data) {
      AudioAlertService.playErrorAlert();
      state = state.copyWith(
        clearTrip: true,
        errorMessage: 'This booking was cancelled by the requester/dispatcher.',
      );
      _ref.read(driverLocationProvider.notifier).stopTracking();
    });

    _reverbDestinationSub?.cancel();
    _reverbDestinationSub = reverb.onDestinationChanged.listen((data) {
      if (state.trip != null && data['hospital_name'] != null) {
        AudioAlertService.playDispatchAlert();
        final updated = state.trip!.copyWith(
          destinationHospital: data['hospital_name'].toString(),
          destinationAddress: data['hospital_address']?.toString(),
          destinationLatitude: (data['latitude'] as num?)?.toDouble(),
          destinationLongitude: (data['longitude'] as num?)?.toDouble(),
        );
        state = state.copyWith(
          trip: updated,
          lastActionMessage: 'Destination hospital updated by dispatcher.',
        );
      }
    });
  }

  void clearTrip() {
    state = state.copyWith(clearTrip: true);
    _ref.read(driverLocationProvider.notifier).stopTracking();
    _ref.read(reverbServiceProvider).unsubscribeBookingChannel();
  }

  @override
  void dispose() {
    _reverbCancellationSub?.cancel();
    _reverbDestinationSub?.cancel();
    super.dispose();
  }
}

final activeTripProvider = StateNotifierProvider<ActiveTripNotifier, ActiveTripState>((ref) {
  final repo = ref.watch(activeTripRepositoryProvider);
  return ActiveTripNotifier(repo, ref);
});
