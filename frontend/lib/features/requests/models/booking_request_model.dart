/// Emergency Booking Dispatch Request model
class BookingRequestModel {
  final int id;
  final String bookingReference;
  final String? patientName;
  final String? patientPhone;
  final String pickupAddress;
  final String? pickupLandmark;
  final double pickupLatitude;
  final double pickupLongitude;
  final String? destinationHospital;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String emergencyCategory;
  final String essentialInstructions;
  final double distanceMeters;
  final int estimatedEtaMinutes;
  final int countdownSeconds;
  final DateTime createdAt;

  BookingRequestModel({
    required this.id,
    required this.bookingReference,
    this.patientName,
    this.patientPhone,
    required this.pickupAddress,
    this.pickupLandmark,
    required this.pickupLatitude,
    required this.pickupLongitude,
    this.destinationHospital,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.emergencyCategory = 'Critical',
    required this.essentialInstructions,
    this.distanceMeters = 0.0,
    this.estimatedEtaMinutes = 0,
    this.countdownSeconds = 120,
    required this.createdAt,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    String destHospital = 'Emergency Trauma Center';
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
        'Casualty & Emergency Bay';

    return BookingRequestModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 101,
      bookingReference:
          json['booking_reference']?.toString() ??
          'BK-${DateTime.now().millisecondsSinceEpoch % 100000}',
      patientName: json['patient_name']?.toString() ?? '',
      patientPhone: json['patient_phone']?.toString() ?? '',
      pickupAddress:
          json['pickup_address']?.toString() ?? 'Patient Pickup Location',
      pickupLandmark: json['pickup_landmark']?.toString(),
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      destinationHospital: destHospital,
      destinationAddress: destAddress,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      emergencyCategory: json['emergency_category']?.toString() ?? 'Critical',
      essentialInstructions: json['essential_instructions']?.toString() ?? 'Patient having severe emergency. Oxygen & Stretcher required immediately.',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      estimatedEtaMinutes:
          (json['estimated_eta_minutes'] as num?)?.toInt() ?? 0,
      countdownSeconds: (json['countdown_seconds'] as num?)?.toInt() ?? 120,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
