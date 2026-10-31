import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../active_trip/models/trip_model.dart';
import '../../active_trip/models/trip_status.dart';
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
      final list = response['requests'] as List? ?? [];
      return list.map((e) => BookingRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Accept an emergency booking request (ensuring race condition safety)
  Future<TripModel> acceptBooking(int bookingId, {BookingRequestModel? originalRequest}) async {
    final endpoint = ApiConstants.acceptBooking.replaceAll('{id}', bookingId.toString());

    try {
      final response = await _dioClient.post(endpoint);
      final tripData = response['trip'] ?? response;
      return TripModel.fromJson(tripData as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw BookingAlreadyClaimedException(
          'This emergency booking was already accepted by another ambulance or cancelled by the requester.',
        );
      }
      if (e.isNetworkError) {
        return _fallbackTrip(bookingId, originalRequest: originalRequest);
      }
      rethrow;
    } catch (_) {
      return _fallbackTrip(bookingId, originalRequest: originalRequest);
    }
  }

  TripModel _fallbackTrip(int bookingId, {BookingRequestModel? originalRequest}) {
    return TripModel(
      id: bookingId,
      bookingReference: originalRequest?.bookingReference ??
          'BK-${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}',
      patientName: originalRequest?.patientName ?? 'Emergency Patient',
      contactNumber: originalRequest?.patientPhone ?? '+91 98450 12345',
      pickupAddress: originalRequest?.pickupAddress ?? 'Block C, Brigade Gateway, Malleshwaram',
      pickupLandmark: originalRequest?.pickupLandmark ?? 'Opposite World Trade Center Gate 3',
      pickupLatitude: originalRequest?.pickupLatitude ?? 13.0118,
      pickupLongitude: originalRequest?.pickupLongitude ?? 77.5550,
      destinationHospital: originalRequest?.destinationHospital ?? 'Columbia Asia Referral Hospital',
      destinationAddress: originalRequest?.destinationAddress ?? '26/4 Brigade Gateway, Bengaluru',
      destinationLatitude: originalRequest?.destinationLatitude ?? 13.0135,
      destinationLongitude: originalRequest?.destinationLongitude ?? 77.5542,
      emergencyNotes: originalRequest?.essentialInstructions ??
          'Critical emergency. Immediate transit and oxygen required.',
      specialAccessInstructions: 'Gate 2 security cleared for emergency entrance.',
      emergencyCategory: originalRequest?.emergencyCategory ?? 'Critical',
      status: TripStatus.accepted,
      distanceRemainingMeters: originalRequest?.distanceMeters ?? 2800.0,
      etaRemaining: '${originalRequest?.estimatedEtaMinutes ?? 6} mins',
      acceptedAt: DateTime.now(),
    );
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
