/// Today's dispatch metrics, active assignments, and shift summary
class DashboardSummaryModel {
  final int completedTripsToday;
  final double distanceCoveredKm;
  final double onlineHours;
  final double earningsToday;
  final int emergencyCriticalTrips;
  final bool hasActiveTrip;
  final String? activeTripId;

  DashboardSummaryModel({
    this.completedTripsToday = 0,
    this.distanceCoveredKm = 0.0,
    this.onlineHours = 0.0,
    this.earningsToday = 0.0,
    this.emergencyCriticalTrips = 0,
    this.hasActiveTrip = false,
    this.activeTripId,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      completedTripsToday: json['completed_trips_today'] as int? ?? 0,
      distanceCoveredKm: (json['distance_covered_km'] as num?)?.toDouble() ?? 0.0,
      onlineHours: (json['online_hours'] as num?)?.toDouble() ?? 0.0,
      earningsToday: (json['earnings_today'] as num?)?.toDouble() ?? 0.0,
      emergencyCriticalTrips: json['emergency_critical_trips'] as int? ?? 0,
      hasActiveTrip: json['has_active_trip'] as bool? ?? false,
      activeTripId: json['active_trip_id'] as String?,
    );
  }

  DashboardSummaryModel copyWith({
    int? completedTripsToday,
    double? distanceCoveredKm,
    double? onlineHours,
    double? earningsToday,
    int? emergencyCriticalTrips,
    bool? hasActiveTrip,
    String? activeTripId,
  }) {
    return DashboardSummaryModel(
      completedTripsToday: completedTripsToday ?? this.completedTripsToday,
      distanceCoveredKm: distanceCoveredKm ?? this.distanceCoveredKm,
      onlineHours: onlineHours ?? this.onlineHours,
      earningsToday: earningsToday ?? this.earningsToday,
      emergencyCriticalTrips: emergencyCriticalTrips ?? this.emergencyCriticalTrips,
      hasActiveTrip: hasActiveTrip ?? this.hasActiveTrip,
      activeTripId: activeTripId ?? this.activeTripId,
    );
  }
}
