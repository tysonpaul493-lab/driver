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
      if (response == null || response['trip'] == null || response['trip'] is! Map) {
        await _storageService.setActiveBookingId(null);
        return null;
      }
      final trip = TripModel.fromJson(Map<String, dynamic>.from(response['trip'] as Map));
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

      final rawTrip = response is Map ? (response['trip'] ?? response) : null;
      final tripMap = rawTrip is Map ? Map<String, dynamic>.from(rawTrip) : <String, dynamic>{};
      final updated = TripModel.fromJson(tripMap);
      if (newStatus.isFinished) {
        await _storageService.setActiveBookingId(null);
      }
      return updated;
    } catch (_) {
      if (newStatus.isFinished) {
        await _storageService.setActiveBookingId(null);
      }
      rethrow;
    }
  }

  /// Fetch real-time chat history for an active trip
  Future<List<Map<String, dynamic>>> getChatMessages(int tripId) async {
    try {
      final response = await _dioClient.get('/bookings/$tripId/chat');
      final list = response['messages'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Send a chat reply from the ambulance driver to the requester
  Future<Map<String, dynamic>?> sendChatMessage(int tripId, String message) async {
    try {
      final response = await _dioClient.post(
        '/bookings/$tripId/chat',
        data: {
          'sender': 'driver',
          'message': message.trim(),
        },
      );
      if (response is Map<String, dynamic> && response['entry'] is Map<String, dynamic>) {
        return response['entry'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
