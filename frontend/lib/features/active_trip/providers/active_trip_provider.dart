import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/driver_notification_service.dart';
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
  final List<Map<String, dynamic>> chatMessages;
  final int unreadChatCount;
  final String? cancelledTripRef;
  final String? cancelledReason;

  const ActiveTripState({
    this.trip,
    this.isLoading = false,
    this.errorMessage,
    this.lastActionMessage,
    this.chatMessages = const [],
    this.unreadChatCount = 0,
    this.cancelledTripRef,
    this.cancelledReason,
  });

  bool get hasActiveTrip => trip != null && !trip!.status.isFinished;

  ActiveTripState copyWith({
    TripModel? trip,
    bool? isLoading,
    String? errorMessage,
    String? lastActionMessage,
    List<Map<String, dynamic>>? chatMessages,
    int? unreadChatCount,
    String? cancelledTripRef,
    String? cancelledReason,
    bool clearTrip = false,
    bool clearCancelled = false,
  }) {
    return ActiveTripState(
      trip: clearTrip ? null : (trip ?? this.trip),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
      chatMessages: clearTrip ? const [] : (chatMessages ?? this.chatMessages),
      unreadChatCount: clearTrip ? 0 : (unreadChatCount ?? this.unreadChatCount),
      cancelledTripRef: clearCancelled ? null : (cancelledTripRef ?? this.cancelledTripRef),
      cancelledReason: clearCancelled ? null : (cancelledReason ?? this.cancelledReason),
    );
  }
}

class ActiveTripNotifier extends StateNotifier<ActiveTripState> {
  final ActiveTripRepository _repository;
  final Ref _ref;
  StreamSubscription? _reverbCancellationSub;
  StreamSubscription? _reverbDestinationSub;
  StreamSubscription? _reverbChatSub;
  Timer? _activeTripSyncTimer;

  ActiveTripNotifier(this._repository, this._ref) : super(const ActiveTripState()) {
    checkActiveTrip();
  }

  /// Check if there is an in-flight trip (e.g. app restart or crash recovery)
  Future<void> checkActiveTrip() async {
    state = state.copyWith(isLoading: true);
    try {
      final trip = await _repository.getActiveTrip();
      if (trip != null && !trip.status.isFinished) {
        final history = await _repository.getChatMessages(trip.id);
        state = state.copyWith(
          trip: trip,
          isLoading: false,
          chatMessages: history,
        );
        _subscribeToTripEvents(trip.id);
        _startTripSyncTimer();
        // Ensure location tracking is active for this trip
        _ref.read(driverLocationProvider.notifier).startTracking(
          bookingReference: trip.bookingReference,
        );
      } else {
        _activeTripSyncTimer?.cancel();
        state = state.copyWith(isLoading: false, clearTrip: true);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Set trip right after accepting a dispatch request
  void setTrip(TripModel trip) {
    state = state.copyWith(
      trip: trip,
      isLoading: false,
      chatMessages: const [],
      unreadChatCount: 0,
      clearCancelled: true,
    );
    _subscribeToTripEvents(trip.id);
    _startTripSyncTimer();
    refreshChat();
    _ref.read(driverLocationProvider.notifier).startTracking(
      bookingReference: trip.bookingReference,
    );
  }

  void _startTripSyncTimer() {
    _activeTripSyncTimer?.cancel();
    _activeTripSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!state.hasActiveTrip) {
        _activeTripSyncTimer?.cancel();
        return;
      }
      try {
        final serverTrip = await _repository.getActiveTrip();
        // Strict guard: NEVER cancel on null/empty/network errors.
        // Only cancel if server explicitly confirms the trip is cancelled.
        if (serverTrip != null && serverTrip.status == TripStatus.cancelled) {
          final refNum = state.trip?.bookingReference ?? serverTrip.bookingReference;
          await _handleTripCancellation(refNum, serverTrip.handoverNotes ?? 'Cancelled by requester');
        }
      } catch (_) {}
    });
  }

  Future<void> _handleTripCancellation(String refNum, String reason) async {
    _activeTripSyncTimer?.cancel();
    _activeTripSyncTimer = null;

    await AudioAlertService.playErrorAlert();
    DriverNotificationService.instance.showSystemAlert(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: '⚠️ Emergency Trip Cancelled: $refNum',
      body: 'The user has cancelled this emergency trip ($reason). Navigation has been stopped.',
    );

    final storage = _ref.read(storageServiceProvider);
    await storage.setActiveBookingId(null);
    await _ref.read(driverLocationProvider.notifier).stopTracking();
    try {
      await _ref.read(reverbServiceProvider).unsubscribeBookingChannel();
    } catch (_) {}

    state = state.copyWith(
      clearTrip: true,
      cancelledTripRef: refNum,
      cancelledReason: reason,
      errorMessage: 'This emergency trip was cancelled by the requester ($reason).',
    );

    _ref.invalidate(dashboardSummaryProvider);
    _ref.invalidate(tripHistoryProvider);
  }

  void dismissCancellation() {
    state = state.copyWith(clearCancelled: true);
  }

  Future<void> refreshChat() async {
    final trip = state.trip;
    if (trip == null) return;
    final history = await _repository.getChatMessages(trip.id);
    if (history.isNotEmpty) {
      state = state.copyWith(chatMessages: history);
    }
  }

  Future<void> sendChatMessage(String text) async {
    final trip = state.trip;
    final trimmed = text.trim();
    if (trip == null || trimmed.isEmpty) return;

    final optimistic = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender': 'driver',
      'message': trimmed,
      'timestamp': DateTime.now().toIso8601String(),
    };
    state = state.copyWith(chatMessages: [...state.chatMessages, optimistic]);

    final saved = await _repository.sendChatMessage(trip.id, trimmed);
    if (saved != null) {
      final list = List<Map<String, dynamic>>.from(state.chatMessages);
      if (list.isNotEmpty) list[list.length - 1] = saved;
      state = state.copyWith(chatMessages: list);
    }
  }

  void markChatRead() {
    if (state.unreadChatCount > 0) {
      state = state.copyWith(unreadChatCount: 0);
    }
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
      // Offline fallback: update local trip model cleanly without losing real patient/hospital info
      final now = DateTime.now();
      final updated = currentTrip.copyWith(
        status: next,
        arrivedPickupAt: next == TripStatus.arrivedAtPickup ? now : currentTrip.arrivedPickupAt,
        patientPickedUpAt: next == TripStatus.patientOnboard ? now : currentTrip.patientPickedUpAt,
        completedAt: next == TripStatus.completed ? now : currentTrip.completedAt,
        handoverNotes: handoverNotes ?? currentTrip.handoverNotes,
      );
      await AudioAlertService.playActionConfirmed();
      if (next.isFinished) {
        final storage = _ref.read(storageServiceProvider);
        await storage.setActiveBookingId(null);
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
        lastActionMessage: next.isFinished
            ? 'Emergency trip successfully completed.'
            : 'Step updated to: ${next.displayTitle}',
      );
      return true;
    }
  }

  void _subscribeToTripEvents(int tripId) {
    final reverb = _ref.read(reverbServiceProvider);
    reverb.subscribeToBookingChannel(tripId);

    _reverbCancellationSub?.cancel();
    _reverbCancellationSub = reverb.onBookingCancelled.listen((data) {
      final currentTrip = state.trip;
      if (currentTrip == null) return;

      final incomingId = data['booking_id'] != null 
          ? int.tryParse(data['booking_id'].toString()) 
          : (data['id'] != null ? int.tryParse(data['id'].toString()) : null);
      final incomingRef = data['booking_reference']?.toString();

      // Strict check: only cancel if this specific trip matches
      final matchesId = incomingId != null && incomingId == currentTrip.id;
      final matchesRef = incomingRef != null && incomingRef.isNotEmpty && incomingRef == currentTrip.bookingReference;

      if (!matchesId && !matchesRef) {
        // Event belongs to a different trip or is a general broadcast - do not cancel active trip!
        return;
      }

      final refNum = currentTrip.bookingReference;
      final reason = data['reason']?.toString() ?? 'Cancelled by requester';
      _handleTripCancellation(refNum, reason);
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

    _reverbChatSub?.cancel();
    _reverbChatSub = reverb.onChatMessage.listen((data) {
      final sender = data['sender']?.toString() ?? '';
      final msg = data['message']?.toString().trim() ?? '';
      if (msg.isEmpty || sender == 'driver') return;

      final id = data['id'];
      final alreadyExists = (id != null && state.chatMessages.any((m) => m['id']?.toString() == id.toString())) ||
          state.chatMessages.any((m) =>
              m['message']?.toString().trim() == msg &&
              m['sender']?.toString() == sender);
      if (alreadyExists) return;

      AudioAlertService.playDispatchAlert();
      DriverNotificationService.instance.showChatNotification(
        id: (id is int ? id : DateTime.now().millisecondsSinceEpoch % 100000),
        title: '💬 Message from Patient / Dispatch',
        body: msg,
      );
      state = state.copyWith(
        chatMessages: [...state.chatMessages, data],
        unreadChatCount: state.unreadChatCount + 1,
      );
    });
  }

  void clearTrip() {
    _activeTripSyncTimer?.cancel();
    _activeTripSyncTimer = null;
    state = state.copyWith(clearTrip: true);
    _ref.read(driverLocationProvider.notifier).stopTracking();
    _ref.read(reverbServiceProvider).unsubscribeBookingChannel();
  }

  @override
  void dispose() {
    _activeTripSyncTimer?.cancel();
    _activeTripSyncTimer = null;
    _reverbCancellationSub?.cancel();
    _reverbDestinationSub?.cancel();
    _reverbChatSub?.cancel();
    super.dispose();
  }
}

final activeTripProvider = StateNotifierProvider<ActiveTripNotifier, ActiveTripState>((ref) {
  final repo = ref.watch(activeTripRepositoryProvider);
  return ActiveTripNotifier(repo, ref);
});
