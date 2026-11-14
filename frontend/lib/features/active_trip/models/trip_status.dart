/// Lifecycle states for an ambulance dispatch trip
enum TripStatus {
  accepted('accepted', 'Assignment Accepted', 'NAVIGATE TO PATIENT', 1),
  enRouteToPickup('en_route_to_pickup', 'En Route to Patient', 'MARK ARRIVED AT PICKUP', 2),
  arrivedAtPickup('arrived_at_pickup', 'Arrived at Pickup', 'CONFIRM PATIENT PICKUP', 3),
  patientOnboard('patient_onboard', 'Patient Onboard', 'START TRIP TO HOSPITAL', 4),
  inTransitToHospital('in_transit_to_hospital', 'In Transit to Hospital', 'ARRIVED AT HOSPITAL', 5),
  arrivedAtHospital('arrived_at_hospital', 'Arrived at Hospital', 'COMPLETE TRIP & HANDOVER', 6),
  completed('completed', 'Trip Completed', 'FINISH', 7),
  cancelled('cancelled', 'Trip Cancelled', 'DISMISSED', 0);

  final String apiValue;
  final String displayTitle;
  final String nextActionLabel;
  final int stepIndex;

  const TripStatus(this.apiValue, this.displayTitle, this.nextActionLabel, this.stepIndex);

  static TripStatus fromApi(String? val) {
    final normalized = val?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'accepted':
      case 'driver_assigned':
      case 'driverassigned':
        return TripStatus.accepted;
      case 'en_route_to_pickup':
      case 'enroutetopickup':
      case 'driver_approaching':
      case 'driverapproaching':
        return TripStatus.enRouteToPickup;
      case 'arrived_at_pickup':
      case 'arrivedatpickup':
      case 'driver_arrived':
      case 'driverarrived':
        return TripStatus.arrivedAtPickup;
      case 'patient_onboard':
      case 'patientonboard':
      case 'patient_picked_up':
      case 'patientpickedup':
        return TripStatus.patientOnboard;
      case 'in_transit_to_hospital':
      case 'intransittohospital':
      case 'traveling_to_hospital':
      case 'travelingtohospital':
        return TripStatus.inTransitToHospital;
      case 'arrived_at_hospital':
      case 'arrivedathospital':
        return TripStatus.arrivedAtHospital;
      case 'completed':
      case 'trip_completed':
      case 'tripcompleted':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        for (final s in TripStatus.values) {
          if (s.apiValue == normalized || s.name.toLowerCase() == normalized) return s;
        }
        return TripStatus.accepted;
    }
  }

  TripStatus? get nextStatus {
    switch (this) {
      case TripStatus.accepted:
        return TripStatus.enRouteToPickup;
      case TripStatus.enRouteToPickup:
        return TripStatus.arrivedAtPickup;
      case TripStatus.arrivedAtPickup:
        return TripStatus.patientOnboard;
      case TripStatus.patientOnboard:
        return TripStatus.inTransitToHospital;
      case TripStatus.inTransitToHospital:
        return TripStatus.arrivedAtHospital;
      case TripStatus.arrivedAtHospital:
        return TripStatus.completed;
      case TripStatus.completed:
      case TripStatus.cancelled:
        return null;
    }
  }

  bool get isHeadingToPickup =>
      this == TripStatus.accepted || this == TripStatus.enRouteToPickup;

  bool get isHeadingToHospital =>
      this == TripStatus.patientOnboard ||
      this == TripStatus.inTransitToHospital ||
      this == TripStatus.arrivedAtHospital;

  bool get isFinished => this == TripStatus.completed || this == TripStatus.cancelled;
}
