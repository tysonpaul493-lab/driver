import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';

class ActiveTripRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  ActiveTripRepository(this._dioClient, this._storageService);

  /// Fetch current ongoing trip from backend
  Future<TripModel?> getActiveTrip() async {
    try {
      final response = await _dioClient.get(ApiConstants.activeTrip);
      if (response == null || response['trip'] == null) {
        await _storageService.setActiveBookingId(null);
        return null;
      }
      final trip = TripModel.fromJson(response['trip'] as Map<String, dynamic>);
      await _storageService.setActiveBookingId(trip.bookingReference);
      return trip;
    } catch (_) {
      return null;
    }
  }

  /// Progress the trip through server-validated state machine
  Future<TripModel> updateTripStatus({
    required int tripId,
    required TripStatus newStatus,
    double? latitude,
    double? longitude,
    String? handoverNotes,
  }) async {
    final endpoint = ApiConstants.updateTripStatus.replaceAll('{id}', tripId.toString());

    try {
      final response = await _dioClient.patch(
        endpoint,
        data: {
          'status': newStatus.apiValue,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'handover_notes': ?handoverNotes,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final updated = TripModel.fromJson(response['trip'] ?? response);
      if (newStatus.isFinished) {
        await _storageService.setActiveBookingId(null);
      }
      return updated;
    } catch (_) {
      // In offline demo mode, advance the trip locally
      if (newStatus.isFinished) {
        await _storageService.setActiveBookingId(null);
      }
      return TripModel(
        id: tripId,
        bookingReference: 'BK-89241',
        pickupAddress: 'Flat 402, Sunrise Towers, MG Road',
        pickupLandmark: 'Near Metro Pillar #142',
        pickupLatitude: latitude ?? 12.9716,
        pickupLongitude: longitude ?? 77.5946,
        destinationHospital: 'Apollo Emergency & Trauma Care',
        destinationAddress: '154 Bannerghatta Main Rd',
        destinationLatitude: 12.9081,
        destinationLongitude: 77.6006,
        emergencyNotes: 'Critical emergency care in transit.',
        specialAccessInstructions: 'Gate 2 security cleared.',
        emergencyCategory: 'Critical',
        status: newStatus,
        distanceRemainingMeters: 1200.0,
        etaRemaining: '4 mins',
        acceptedAt: DateTime.now(),
      );
    }
  }
}
