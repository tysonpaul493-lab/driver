import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/driver_notification_service.dart';
import '../../../core/utils/audio_alert_service.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../../active_trip/providers/active_trip_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../models/booking_request_model.dart';
import '../repositories/requests_repository.dart';

final requestsRepositoryProvider = Provider<RequestsRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return RequestsRepository(dio);
});

class RequestsState {
  final List<BookingRequestModel> pendingRequests;
  final BookingRequestModel? currentIncomingRequest;
  final bool isAccepting;
  final String? conflictMessage;
  final String? errorMessage;

  const RequestsState({
    this.pendingRequests = const [],
    this.currentIncomingRequest,
    this.isAccepting = false,
    this.conflictMessage,
    this.errorMessage,
  });

  RequestsState copyWith({
    List<BookingRequestModel>? pendingRequests,
    BookingRequestModel? currentIncomingRequest,
    bool? isAccepting,
    String? conflictMessage,
    String? errorMessage,
    bool clearCurrentRequest = false,
  }) {
    return RequestsState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      currentIncomingRequest: clearCurrentRequest
          ? null
          : (currentIncomingRequest ?? this.currentIncomingRequest),
      isAccepting: isAccepting ?? this.isAccepting,
      conflictMessage: conflictMessage,
      errorMessage: errorMessage,
    );
  }
}

class RequestsNotifier extends StateNotifier<RequestsState> {
  final RequestsRepository _repository;
  final Ref _ref;
  StreamSubscription? _reverbRequestSub;
  StreamSubscription? _reverbClaimedSub;
  StreamSubscription? _reverbCancelledSub;
  Timer? _pendingPoller;
  final Set<int> _declinedBookingIds = {};

  RequestsNotifier(this._repository, this._ref) : super(const RequestsState()) {
    _initWebsocketListeners();
    _startPendingRequestsPoller();
  }

  bool _isPollingPending = false;
  int _pollerTick = 0;

  void _startPendingRequestsPoller() {
    _pendingPoller?.cancel();
    _pollerTick = 0;
    _pendingPoller = Timer.periodic(const Duration(seconds: 4), (_) async {
      final isOnline = _ref.read(onlineStatusProvider).isOnline;
      final activeTrip = _ref.read(activeTripProvider);
      if (!isOnline || activeTrip.hasActiveTrip) return;

      if (_isPollingPending) return;

      // When WebSocket is connected, incoming bookings are pushed instantaneously.
      // Poll REST API once every 12s as a safety fallback.
      final reverb = _ref.read(reverbServiceProvider);
      if (reverb.isConnected) {
        _pollerTick = (_pollerTick + 1) % 3;
        if (_pollerTick != 0) return;
      }

      _isPollingPending = true;
      try {
        final rawPending = await _repository.getPendingRequests();
        final seenIds = <int>{};
        final pending = <BookingRequestModel>[];
        for (final p in rawPending) {
          if (!_declinedBookingIds.contains(p.id) && seenIds.add(p.id)) {
            pending.add(p);
          }
        }
        if (pending.isNotEmpty) {
          final first = pending.first;
          _ref.read(notificationsProvider.notifier).addBookingAlert(first);

          if (state.currentIncomingRequest == null) {
            AudioAlertService.playDispatchAlert();
            DriverNotificationService.instance.showDispatchAlert(
              id: first.id,
              title: '🚨 Emergency Dispatch: ${first.emergencyCategory}',
              body: 'Pickup: ${first.pickupAddress}. Tap to respond.',
              payload: first.bookingReference,
            );
            state = state.copyWith(
              pendingRequests: pending,
              currentIncomingRequest: first,
              conflictMessage: null,
              errorMessage: null,
            );
          } else if (!pending.any(
            (p) => p.id == state.currentIncomingRequest!.id,
          )) {
            // Already accepted by another driver unit!
            state = state.copyWith(
              pendingRequests: pending,
              clearCurrentRequest: true,
              conflictMessage:
                  'This booking was accepted by another ambulance unit.',
            );
          } else {
            state = state.copyWith(pendingRequests: pending);
          }
        } else if (state.currentIncomingRequest != null) {
          // No more pending requests: another driver claimed it
          state = state.copyWith(
            pendingRequests: const [],
            clearCurrentRequest: true,
            conflictMessage:
                'This booking was accepted by another ambulance unit.',
          );
        } else if (state.pendingRequests.isNotEmpty) {
          state = state.copyWith(pendingRequests: const []);
        }
      } catch (_) {} finally {
        _isPollingPending = false;
      }
    });
  }

  void _initWebsocketListeners() {
    final reverb = _ref.read(reverbServiceProvider);

    _reverbRequestSub = reverb.onBookingRequest.listen((data) {
      if (!_ref.read(onlineStatusProvider).isOnline ||
          _ref.read(activeTripProvider).hasActiveTrip) {
        return;
      }
      final request = BookingRequestModel.fromJson(data);
      if (_declinedBookingIds.contains(request.id)) return;
      // Play high priority dispatch alert tone & vibration
      AudioAlertService.playDispatchAlert();
      DriverNotificationService.instance.showDispatchAlert(
        id: request.id,
        title: '🚨 Emergency Dispatch: ${request.emergencyCategory}',
        body: 'Pickup: ${request.pickupAddress}. Tap to respond.',
        payload: request.bookingReference,
      );
      // Add alert with user details to Notifications screen
      _ref.read(notificationsProvider.notifier).addBookingAlert(request);
      state = state.copyWith(
        currentIncomingRequest: request,
        conflictMessage: null,
        errorMessage: null,
      );
    });

    _reverbClaimedSub = reverb.onBookingClaimedByOther.listen((data) {
      final bookingId = int.tryParse(data['booking_id']?.toString() ?? '') ??
          int.tryParse(data['id']?.toString() ?? '');
      final bookingRef = data['booking_reference']?.toString();

      final remainingPending = state.pendingRequests.where((p) {
        if (bookingId != null && p.id == bookingId) return false;
        if (bookingRef != null && p.bookingReference == bookingRef) return false;
        return true;
      }).toList();

      final isCurrent = state.currentIncomingRequest != null &&
          ((bookingId != null && state.currentIncomingRequest!.id == bookingId) ||
              (bookingRef != null &&
                  state.currentIncomingRequest!.bookingReference == bookingRef));

      if (isCurrent) {
        AudioAlertService.playErrorAlert();
        if (bookingId != null) {
          DriverNotificationService.instance.cancel(bookingId);
        }
        state = state.copyWith(
          pendingRequests: remainingPending,
          clearCurrentRequest: true,
          conflictMessage:
              'This emergency booking was accepted by another ambulance unit.',
        );
      } else {
        if (bookingId != null) {
          DriverNotificationService.instance.cancel(bookingId);
        }
        state = state.copyWith(pendingRequests: remainingPending);
      }
    });

    _reverbCancelledSub = reverb.onBookingCancelled.listen((data) {
      final bookingId = int.tryParse(data['booking_id']?.toString() ?? '') ??
          int.tryParse(data['id']?.toString() ?? '');
      final bookingRef = data['booking_reference']?.toString();

      final remainingPending = state.pendingRequests.where((p) {
        if (bookingId != null && p.id == bookingId) return false;
        if (bookingRef != null && p.bookingReference == bookingRef) return false;
        return true;
      }).toList();

      final isCurrent = state.currentIncomingRequest != null &&
          ((bookingId != null && state.currentIncomingRequest!.id == bookingId) ||
              (bookingRef != null &&
                  state.currentIncomingRequest!.bookingReference == bookingRef));

      if (bookingId != null) {
        DriverNotificationService.instance.cancel(bookingId);
      }

      if (isCurrent) {
        state = state.copyWith(
          pendingRequests: remainingPending,
          clearCurrentRequest: true,
          conflictMessage: 'This emergency request was cancelled by the user.',
        );
      } else {
        state = state.copyWith(pendingRequests: remainingPending);
      }
    });
  }

  /// Simulate incoming booking for manual testing or demo dispatch
  void simulateIncomingRequest(BookingRequestModel request) {
    AudioAlertService.playDispatchAlert();
    state = state.copyWith(
      currentIncomingRequest: request,
      conflictMessage: null,
      errorMessage: null,
    );
  }

  /// Accept an emergency request (protecting against race conditions)
  Future<bool> acceptRequest(int bookingId) async {
    state = state.copyWith(
      isAccepting: true,
      errorMessage: null,
      conflictMessage: null,
    );

    try {
      final trip = await _repository.acceptBooking(
        bookingId,
        originalRequest: state.currentIncomingRequest,
      );

      // Save driver basic details so they are synced to user app
      final driver = _ref.read(currentDriverProvider);
      final storage = _ref.read(storageServiceProvider);
      await storage.saveAcceptedDriverInfo({
        'booking_id': bookingId,
        'booking_reference': trip.bookingReference,
        'driver_id': driver?.id ?? 0,
        'driver_name': driver?.name.isNotEmpty == true ? driver!.name : '',
        'driver_phone': driver?.phone.isNotEmpty == true ? driver!.phone : '',
        'ambulance_plate':
            driver?.assignedVehicle?.registrationNumber ?? '',
        'vehicle_type':
            driver?.assignedVehicle?.vehicleType.displayName ??
            'Emergency Ambulance',
        'vehicle_model':
            driver?.assignedVehicle?.makeModel ?? '',
        'driver_rating': driver?.rating ?? 5.0,
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      });

      // Pass the accepted trip to ActiveTripNotifier
      _ref.read(activeTripProvider.notifier).setTrip(trip);

      state = state.copyWith(isAccepting: false, clearCurrentRequest: true);
      return true;
    } on BookingAlreadyClaimedException catch (e) {
      AudioAlertService.playErrorAlert();
      state = state.copyWith(
        isAccepting: false,
        pendingRequests: state.pendingRequests
            .where((p) => p.id != bookingId)
            .toList(),
        clearCurrentRequest: true,
        conflictMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isAccepting: false,
        errorMessage: 'Failed to accept booking: $e',
      );
      return false;
    }
  }

  /// Decline request
  Future<void> declineRequest(int bookingId, {String? reason}) async {
    _declinedBookingIds.add(bookingId);
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((p) => p.id != bookingId)
          .toList(),
      clearCurrentRequest: true,
      conflictMessage: null,
      errorMessage: null,
    );

    try {
      await _repository.declineBooking(bookingId, reason: reason);
    } catch (_) {}
  }

  void dismissConflictMessage() {
    state = state.copyWith(conflictMessage: null);
  }

  @override
  void dispose() {
    _pendingPoller?.cancel();
    _reverbRequestSub?.cancel();
    _reverbClaimedSub?.cancel();
    _reverbCancelledSub?.cancel();
    super.dispose();
  }
}

final requestsProvider = StateNotifierProvider<RequestsNotifier, RequestsState>(
  (ref) {
    final repo = ref.watch(requestsRepositoryProvider);
    return RequestsNotifier(repo, ref);
  },
);
