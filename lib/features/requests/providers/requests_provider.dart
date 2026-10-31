import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/audio_alert_service.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../../active_trip/providers/active_trip_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
      currentIncomingRequest: clearCurrentRequest ? null : (currentIncomingRequest ?? this.currentIncomingRequest),
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

  RequestsNotifier(this._repository, this._ref) : super(const RequestsState()) {
    _initWebsocketListeners();
  }

  void _initWebsocketListeners() {
    final reverb = _ref.read(reverbServiceProvider);

    _reverbRequestSub = reverb.onBookingRequest.listen((data) {
      final request = BookingRequestModel.fromJson(data);
      // Play high priority dispatch alert tone & vibration
      AudioAlertService.playDispatchAlert();
      state = state.copyWith(
        currentIncomingRequest: request,
        conflictMessage: null,
        errorMessage: null,
      );
    });

    _reverbClaimedSub = reverb.onBookingClaimedByOther.listen((data) {
      final bookingId = data['booking_id'] as int? ?? data['id'] as int?;
      if (state.currentIncomingRequest != null &&
          (bookingId == null || state.currentIncomingRequest!.id == bookingId)) {
        AudioAlertService.playErrorAlert();
        state = state.copyWith(
          clearCurrentRequest: true,
          conflictMessage: 'This booking was accepted by another ambulance or claimed by dispatch.',
        );
      }
    });

    _reverbCancelledSub = reverb.onBookingCancelled.listen((data) {
      final bookingId = data['booking_id'] as int? ?? data['id'] as int?;
      if (state.currentIncomingRequest != null &&
          (bookingId == null || state.currentIncomingRequest!.id == bookingId)) {
        state = state.copyWith(
          clearCurrentRequest: true,
          conflictMessage: 'This emergency request was cancelled by the user.',
        );
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
    state = state.copyWith(isAccepting: true, errorMessage: null, conflictMessage: null);

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
        'driver_id': driver?.id ?? 1,
        'driver_name': driver?.name.isNotEmpty == true ? driver!.name : 'Rajesh Kumar',
        'driver_phone': driver?.phone.isNotEmpty == true ? driver!.phone : '+91 98765 43210',
        'ambulance_plate': driver?.assignedVehicle?.registrationNumber ?? 'KA-01-EA-1080',
        'vehicle_type': driver?.assignedVehicle?.vehicleType.displayName ?? 'Advanced Life Support (ALS)',
        'vehicle_model': driver?.assignedVehicle?.makeModel ?? 'Force Traveller ICU Ambulance',
        'driver_rating': driver?.rating ?? 5.0,
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      });

      // Pass the accepted trip to ActiveTripNotifier
      _ref.read(activeTripProvider.notifier).setTrip(trip);

      state = state.copyWith(
        isAccepting: false,
        clearCurrentRequest: true,
      );
      return true;
    } on BookingAlreadyClaimedException catch (e) {
      AudioAlertService.playErrorAlert();
      state = state.copyWith(
        isAccepting: false,
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
    try {
      await _repository.declineBooking(bookingId, reason: reason);
    } catch (_) {}

    state = state.copyWith(
      clearCurrentRequest: true,
      conflictMessage: null,
      errorMessage: null,
    );
  }

  void dismissConflictMessage() {
    state = state.copyWith(conflictMessage: null);
  }

  @override
  void dispose() {
    _reverbRequestSub?.cancel();
    _reverbClaimedSub?.cancel();
    _reverbCancelledSub?.cancel();
    super.dispose();
  }
}

final requestsProvider = StateNotifierProvider<RequestsNotifier, RequestsState>((ref) {
  final repo = ref.watch(requestsRepositoryProvider);
  return RequestsNotifier(repo, ref);
});
