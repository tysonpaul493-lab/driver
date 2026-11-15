/// Completed emergency dispatch history item with comprehensive trip metrics & payment tracking
class TripHistoryItem {
  final int id;
  final String bookingReference;
  final String patientName;
  final String? patientPhone;
  final String pickupAddress;
  final String destinationHospital;
  final String emergencyCategory;
  final double distanceKm;
  final int durationMinutes;
  final double earnings;
  final DateTime startedAt;
  final DateTime completedAt;
  final String? handoverNotes;
  final bool isPaid;
  final String paymentStatus;
  final String? paymentMethod;
  final String? ambulancePlate;
  final String status;

  TripHistoryItem({
    required this.id,
    required this.bookingReference,
    required this.patientName,
    this.patientPhone,
    required this.pickupAddress,
    required this.destinationHospital,
    required this.emergencyCategory,
    required this.distanceKm,
    required this.durationMinutes,
    required this.earnings,
    required this.startedAt,
    required this.completedAt,
    this.handoverNotes,
    this.isPaid = true,
    this.paymentStatus = 'Paid',
    this.paymentMethod,
    this.ambulancePlate,
    this.status = 'Completed & Handover Signed',
  });

  TripHistoryItem copyWith({
    int? id,
    String? bookingReference,
    String? patientName,
    String? patientPhone,
    String? pickupAddress,
    String? destinationHospital,
    String? emergencyCategory,
    double? distanceKm,
    int? durationMinutes,
    double? earnings,
    DateTime? startedAt,
    DateTime? completedAt,
    String? handoverNotes,
    bool? isPaid,
    String? paymentStatus,
    String? paymentMethod,
    String? ambulancePlate,
    String? status,
  }) {
    return TripHistoryItem(
      id: id ?? this.id,
      bookingReference: bookingReference ?? this.bookingReference,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationHospital: destinationHospital ?? this.destinationHospital,
      emergencyCategory: emergencyCategory ?? this.emergencyCategory,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      earnings: earnings ?? this.earnings,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      handoverNotes: handoverNotes ?? this.handoverNotes,
      isPaid: isPaid ?? this.isPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      ambulancePlate: ambulancePlate ?? this.ambulancePlate,
      status: status ?? this.status,
    );
  }

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    final distKmVal = (json['distance_km'] as num?)?.toDouble();
    final distMetersVal = (json['distance_remaining_meters'] as num?)?.toDouble();
    final calcDistKm = distKmVal ?? (distMetersVal != null && distMetersVal > 0 ? (distMetersVal / 1000.0) : 6.8);

    final durVal = (json['duration_minutes'] as num?)?.toInt();
    final calcDur = (durVal != null && durVal >= 5 && durVal <= 180)
        ? durVal
        : (calcDistKm * 2.4).round().clamp(10, 60);

    final earnVal = (json['earnings'] as num?)?.toDouble();
    final calcEarn = earnVal ?? (250.0 + (calcDistKm * 28.0));

    final completedStr = json['completed_at'] ?? json['updated_at'] ?? json['accepted_at'] ?? json['created_at'];
    DateTime date = DateTime.now();
    if (completedStr != null) {
      date = (DateTime.tryParse(completedStr.toString()) ?? DateTime.now()).toLocal();
    }

    final startedStr = json['started_at'] ?? json['accepted_at'] ?? json['created_at'];
    DateTime startDate = date.subtract(Duration(minutes: calcDur));
    if (startedStr != null) {
      final parsed = DateTime.tryParse(startedStr.toString())?.toLocal();
      if (parsed != null && parsed.isBefore(date)) {
        startDate = parsed;
      }
    }

    final idVal = json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch % 10000;

    // Check payment status
    bool paid = true;
    String payStatus = 'Paid';
    if (json.containsKey('is_paid')) {
      paid = json['is_paid'] == true || json['is_paid'] == 1 || json['is_paid'] == '1';
      payStatus = paid ? 'Paid' : 'Unpaid';
    } else if (json.containsKey('payment_status')) {
      final p = json['payment_status'].toString().toLowerCase();
      paid = (p == 'paid' || p == 'completed' || p == 'success');
      payStatus = paid ? 'Paid' : 'Pending / Unpaid';
    } else {
      paid = true;
      payStatus = 'Paid';
    }

    return TripHistoryItem(
      id: idVal,
      bookingReference: json['booking_reference'] as String? ?? 'BK-${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}',
      patientName: json['patient_name'] as String? ?? 'Emergency Patient',
      patientPhone: json['patient_phone'] as String? ?? json['contact_number'] as String?,
      pickupAddress: json['pickup_address'] as String? ?? 'Pickup Location',
      destinationHospital: json['destination_hospital'] as String? ?? 'Regional Hospital & Trauma Unit',
      emergencyCategory: json['emergency_category'] as String? ?? 'Critical Emergency',
      distanceKm: double.parse(calcDistKm.toStringAsFixed(1)),
      durationMinutes: calcDur,
      earnings: double.parse(calcEarn.toStringAsFixed(0)),
      startedAt: startDate,
      completedAt: date,
      handoverNotes: json['handover_notes'] as String?,
      isPaid: paid,
      paymentStatus: payStatus,
      paymentMethod: json['payment_method'] as String? ?? '108 Govt Emergency Service',
      ambulancePlate: json['vehicle_plate'] as String? ?? json['registration_number'] as String?,
      status: json['status'] as String? ?? 'Completed & Handover Signed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_reference': bookingReference,
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'pickup_address': pickupAddress,
      'destination_hospital': destinationHospital,
      'emergency_category': emergencyCategory,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'earnings': earnings,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt.toIso8601String(),
      'handover_notes': handoverNotes,
      'is_paid': isPaid,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'vehicle_plate': ambulancePlate,
      'status': status,
    };
  }
}
