import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/dashboard_summary_model.dart';

class DashboardRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  DashboardRepository(this._dioClient, this._storageService);

  Future<DashboardSummaryModel> getSummary() async {
    final completedTrips = await _storageService.getCompletedTrips();
    final localCount = completedTrips.length;
    final localDistance = completedTrips.fold<double>(0.0, (acc, t) {
      final km = (t['distance_km'] as num?)?.toDouble();
      if (km != null) return acc + km;
      final meters = (t['distance_remaining_meters'] as num?)?.toDouble() ?? 3200.0;
      return acc + (meters / 1000.0);
    });
    final localEarnings = completedTrips.fold<double>(
      0.0,
      (acc, t) => acc + ((t['earnings'] as num?)?.toDouble() ?? 0.0),
    );
    final localCritical = completedTrips.where((t) {
      final cat = (t['emergency_category'] ?? '').toString().toLowerCase();
      return cat.contains('critical') || cat.contains('cardiac') || cat.contains('trauma');
    }).length;

    try {
      final response = await _dioClient.get(ApiConstants.dashboardSummary);
      final model = DashboardSummaryModel.fromJson(
        response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{},
      );
      return model.copyWith(
        completedTripsToday: model.completedTripsToday + localCount,
        distanceCoveredKm: model.distanceCoveredKm + localDistance,
        earningsToday: model.earningsToday + localEarnings,
        emergencyCriticalTrips: model.emergencyCriticalTrips + localCritical,
      );
    } catch (_) {
      return DashboardSummaryModel(
        completedTripsToday: localCount,
        distanceCoveredKm: localDistance,
        onlineHours: localCount > 0 ? (localCount * 0.4) : 0.0,
        earningsToday: localEarnings,
        emergencyCriticalTrips: localCritical,
      );
    }
  }

  Future<bool> toggleOnlineStatus(bool online, {double? latitude, double? longitude}) async {
    try {
      final response = await _dioClient.post(
        ApiConstants.toggleOnlineStatus,
        data: {
          'is_online': online,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );

      final status = response['is_online'] as bool? ?? online;
      await _storageService.setOnlineStatus(status);
      return status;
    } catch (_) {
      // In offline demo mode, persist status locally without network error
      await _storageService.setOnlineStatus(online);
      return online;
    }
  }
}
