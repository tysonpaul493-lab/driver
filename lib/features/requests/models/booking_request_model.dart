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
    this.distanceMeters = 2400.0,
    this.estimatedEtaMinutes = 6,
    this.countdownSeconds = 120,
    required this.createdAt,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    return BookingRequestModel(
      id: json['id'] as int? ?? 101,
      bookingReference: json['booking_reference'] as String? ?? 'BK-${DateTime.now().millisecondsSinceEpoch % 100000}',
      patientName: json['patient_name'] as String? ?? 'Emergency Requester',
      patientPhone: json['patient_phone'] as String? ?? '+91 98450 12345',
      pickupAddress: json['pickup_address'] as String? ?? 'Flat 402, Sunrise Towers, MG Road',
      pickupLandmark: json['pickup_landmark'] as String? ?? 'Near Metro Pillar #142',
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble() ?? 12.9716,
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble() ?? 77.5946,
      destinationHospital: json['destination_hospital'] as String? ?? 'Apollo Emergency & Trauma Care',
      destinationAddress: json['destination_address'] as String? ?? '154 Bannerghatta Main Rd',
      destinationLatitude: (json['destination_latitude'] as num?)?.toDouble() ?? 12.9081,
      destinationLongitude: (json['destination_longitude'] as num?)?.toDouble() ?? 77.6006,
      emergencyCategory: json['emergency_category'] as String? ?? 'Critical',
      essentialInstructions: json['essential_instructions'] as String? ??
          'Patient having severe chest pain and breathlessness. Oxygen & Stretcher required immediately.',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 2400.0,
      estimatedEtaMinutes: json['estimated_eta_minutes'] as int? ?? 6,
      countdownSeconds: json['countdown_seconds'] as int? ?? 120,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
