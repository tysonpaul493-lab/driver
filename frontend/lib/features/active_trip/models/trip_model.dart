import 'trip_status.dart';

/// Full active emergency trip model
class TripModel {
  final int id;
  final String bookingReference;
  final String? patientName;
  final String? contactNumber;
  final String pickupAddress;
  final String? pickupLandmark;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destinationHospital;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String emergencyNotes;
  final String specialAccessInstructions;
  final String emergencyCategory;
  final TripStatus status;
  final double distanceRemainingMeters;
  final String etaRemaining;
  final DateTime acceptedAt;
  final DateTime? arrivedPickupAt;
  final DateTime? patientPickedUpAt;
  final DateTime? completedAt;
  final String? handoverNotes;

  TripModel({
    required this.id,
    required this.bookingReference,
    this.patientName,
    this.contactNumber,
    required this.pickupAddress,
    this.pickupLandmark,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationHospital,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.emergencyNotes,
    required this.specialAccessInstructions,
    required this.emergencyCategory,
    required this.status,
    this.distanceRemainingMeters = 0.0,
    this.etaRemaining = '',
    required this.acceptedAt,
    this.arrivedPickupAt,
    this.patientPickedUpAt,
    this.completedAt,
    this.handoverNotes,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    String destHospital = 'Emergency Hospital';
    if (json['destination_hospital'] is String &&
        (json['destination_hospital'] as String).isNotEmpty) {
      destHospital = json['destination_hospital'];
    } else if (json['destination_hospital'] is Map) {
      destHospital =
          json['destination_hospital']['name']?.toString() ??
          json['destination_hospital']['hospital_name']?.toString() ??
          destHospital;
    } else if (json['destination_hospital_name'] != null) {
      destHospital = json['destination_hospital_name'].toString();
    }

    final pickupLat =
        (json['pickup_latitude'] as num?)?.toDouble() ??
        (json['pickup_lat'] as num?)?.toDouble() ??
        12.9716;
    final pickupLng =
        (json['pickup_longitude'] as num?)?.toDouble() ??
        (json['pickup_lng'] as num?)?.toDouble() ??
        77.5946;

    final destLat =
        (json['destination_latitude'] as num?)?.toDouble() ??
        (json['destination_lat'] as num?)?.toDouble() ??
        (json['destination_hospital'] is Map
            ? (json['destination_hospital']['lat'] as num?)?.toDouble() ??
                  (json['destination_hospital']['latitude'] as num?)?.toDouble()
            : null) ??
        (pickupLat + 0.015);

    final destLng =
        (json['destination_longitude'] as num?)?.toDouble() ??
        (json['destination_lng'] as num?)?.toDouble() ??
        (json['destination_hospital'] is Map
            ? (json['destination_hospital']['lng'] as num?)?.toDouble() ??
                  (json['destination_hospital']['longitude'] as num?)
                      ?.toDouble()
            : null) ??
        (pickupLng + 0.012);

    final destAddress =
        (json['destination_address'] as String?) ??
        (json['destination_hospital'] is Map
            ? json['destination_hospital']['address']?.toString()
            : null) ??
        'Casualty & Emergency Ward';

    return TripModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 101,
      bookingReference:
          json['booking_reference']?.toString() ??
          'BK-${DateTime.now().millisecondsSinceEpoch % 100000}',
      patientName:
          json['patient_name']?.toString() ?? json['patientName']?.toString(),
      contactNumber:
          json['contact_number']?.toString() ??
          json['patient_phone']?.toString() ??
          json['callback_phone']?.toString(),
      pickupAddress:
          json['pickup_address']?.toString() ?? 'Patient Pickup Location',
      pickupLandmark: json['pickup_landmark']?.toString(),
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      destinationHospital: destHospital,
      destinationAddress: destAddress,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      emergencyNotes:
          json['emergency_notes']?.toString() ??
          json['essential_instructions']?.toString() ??
          'Patient emergency transit. Oxygen & vital monitoring required.',
      specialAccessInstructions:
          json['special_access_instructions']?.toString() ??
          'Emergency Casualty entrance gate cleared.',
      emergencyCategory: json['emergency_category']?.toString() ?? 'Critical',
      status: TripStatus.fromApi(json['status']?.toString()),
      distanceRemainingMeters: (json['distance_remaining_meters'] as num?)?.toDouble() ?? 0.0,
      etaRemaining: json['eta_remaining']?.toString() ?? '',
      acceptedAt: (json['accepted_at'] ?? json['dispatched_at'] ?? json['created_at']) != null
          ? (DateTime.tryParse((json['accepted_at'] ?? json['dispatched_at'] ?? json['created_at']).toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      arrivedPickupAt: json['arrived_pickup_at'] != null
          ? DateTime.tryParse(json['arrived_pickup_at'].toString())?.toLocal()
          : null,
      patientPickedUpAt: json['patient_picked_up_at'] != null
          ? DateTime.tryParse(json['patient_picked_up_at'].toString())?.toLocal()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
          : null,
      handoverNotes: json['handover_notes'] as String?,
    );
  }

  TripModel copyWith({
    TripStatus? status,
    double? distanceRemainingMeters,
    String? etaRemaining,
    DateTime? arrivedPickupAt,
    DateTime? patientPickedUpAt,
    DateTime? completedAt,
    String? destinationHospital,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? handoverNotes,
  }) {
    return TripModel(
      id: id,
      bookingReference: bookingReference,
      patientName: patientName,
      contactNumber: contactNumber,
      pickupAddress: pickupAddress,
      pickupLandmark: pickupLandmark,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      destinationHospital: destinationHospital ?? this.destinationHospital,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      emergencyNotes: emergencyNotes,
      specialAccessInstructions: specialAccessInstructions,
      emergencyCategory: emergencyCategory,
      status: status ?? this.status,
      distanceRemainingMeters:
          distanceRemainingMeters ?? this.distanceRemainingMeters,
      etaRemaining: etaRemaining ?? this.etaRemaining,
      acceptedAt: acceptedAt,
      arrivedPickupAt: arrivedPickupAt ?? this.arrivedPickupAt,
      patientPickedUpAt: patientPickedUpAt ?? this.patientPickedUpAt,
      completedAt: completedAt ?? this.completedAt,
      handoverNotes: handoverNotes ?? this.handoverNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_reference': bookingReference,
      'patient_name': patientName,
      'contact_number': contactNumber,
      'pickup_address': pickupAddress,
      'pickup_landmark': pickupLandmark,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'destination_hospital': destinationHospital,
      'destination_address': destinationAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'emergency_notes': emergencyNotes,
      'special_access_instructions': specialAccessInstructions,
      'emergency_category': emergencyCategory,
      'status': status.name,
      'distance_remaining_meters': distanceRemainingMeters,
      'eta_remaining': etaRemaining,
      'accepted_at': acceptedAt.toIso8601String(),
      'arrived_pickup_at': arrivedPickupAt?.toIso8601String(),
      'patient_picked_up_at': patientPickedUpAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'handover_notes': handoverNotes,
    };
  }
}
