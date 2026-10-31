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
    this.distanceRemainingMeters = 2400.0,
    this.etaRemaining = '6 mins',
    required this.acceptedAt,
    this.arrivedPickupAt,
    this.patientPickedUpAt,
    this.completedAt,
    this.handoverNotes,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as int? ?? 101,
      bookingReference: json['booking_reference'] as String? ?? 'BK-89241',
      patientName: json['patient_name'] as String?,
      contactNumber: json['contact_number'] as String?,
      pickupAddress: json['pickup_address'] as String? ?? 'Flat 402, Sunrise Towers, MG Road',
      pickupLandmark: json['pickup_landmark'] as String? ?? 'Near Metro Pillar #142',
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble() ?? 12.9716,
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble() ?? 77.5946,
      destinationHospital: json['destination_hospital'] as String? ?? 'Apollo Emergency & Trauma Care',
      destinationAddress: json['destination_address'] as String? ?? '154 Bannerghatta Main Rd',
      destinationLatitude: (json['destination_latitude'] as num?)?.toDouble() ?? 12.9081,
      destinationLongitude: (json['destination_longitude'] as num?)?.toDouble() ?? 77.6006,
      emergencyNotes: json['emergency_notes'] as String? ??
          'Patient having severe chest pain radiating to left arm. Stretcher & Oxygen needed.',
      specialAccessInstructions: json['special_access_instructions'] as String? ??
          'Enter through Gate 2. Elevator is on left side. Security has been alerted.',
      emergencyCategory: json['emergency_category'] as String? ?? 'Cardiac / Critical',
      status: TripStatus.fromApi(json['status'] as String?),
      distanceRemainingMeters: (json['distance_remaining_meters'] as num?)?.toDouble() ?? 2400.0,
      etaRemaining: json['eta_remaining'] as String? ?? '6 mins',
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      arrivedPickupAt: json['arrived_pickup_at'] != null
          ? DateTime.tryParse(json['arrived_pickup_at'].toString())
          : null,
      patientPickedUpAt: json['patient_picked_up_at'] != null
          ? DateTime.tryParse(json['patient_picked_up_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
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
      distanceRemainingMeters: distanceRemainingMeters ?? this.distanceRemainingMeters,
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
