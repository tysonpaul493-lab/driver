import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../active_trip/models/trip_model.dart';
import '../models/booking_request_model.dart';

class BookingAlreadyClaimedException implements Exception {
  final String message;
  BookingAlreadyClaimedException(this.message);
  @override
  String toString() => message;
}

class RequestsRepository {
  final DioClient _dioClient;

  RequestsRepository(this._dioClient);

  Future<List<BookingRequestModel>> getPendingRequests() async {
    try {
      final response = await _dioClient.get(ApiConstants.pendingRequests);
      final list = response is Map && response['requests'] is List ? response['requests'] as List : [];
      return list
          .whereType<Map>()
          .map((e) => BookingRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Accept an emergency booking request (ensuring race condition safety)
  Future<TripModel> acceptBooking(int bookingId, {BookingRequestModel? originalRequest}) async {
    final endpoint = ApiConstants.acceptBooking.replaceAll('{id}', bookingId.toString());

    try {
      final response = await _dioClient.post(endpoint);
      final tripData = (response is Map ? (response['trip'] ?? response) : null);
      return TripModel.fromJson(tripData is Map ? Map<String, dynamic>.from(tripData) : <String, dynamic>{});
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw BookingAlreadyClaimedException(
          'This emergency booking was already accepted by another ambulance or cancelled by the requester.',
        );
      }
      rethrow;
    }
  }

  /// Decline booking so dispatcher can route to next available ambulance
  Future<void> declineBooking(int bookingId, {String? reason}) async {
    final endpoint = ApiConstants.declineBooking.replaceAll('{id}', bookingId.toString());
    try {
      await _dioClient.post(
        endpoint,
        data: {'reason': reason ?? 'Driver declined dispatch'},
      );
    } catch (_) {}
  }
}
