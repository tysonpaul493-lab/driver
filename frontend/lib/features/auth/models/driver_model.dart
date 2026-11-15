import 'vehicle_model.dart';

/// Driver verification status in the system
enum VerificationStatus {
  approved('Approved'),
  pending('Pending Approval'),
  underReview('Under Review'),
  rejected('Rejected'),
  suspended('Suspended');

  final String displayName;
  const VerificationStatus(this.displayName);

  static VerificationStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'verified':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'suspended':
        return VerificationStatus.suspended;
      case 'under_review':
        return VerificationStatus.underReview;
      case 'pending':
      default:
        return VerificationStatus.pending;
    }
  }

  bool get isApproved => this == VerificationStatus.approved;
  bool get isUnderReview =>
      this == VerificationStatus.pending ||
      this == VerificationStatus.underReview;
  bool get isRejected => this == VerificationStatus.rejected;
}

/// Ambulance Driver profile data model
class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String emergencyContact;
  final String licenseNumber;
  final String licenseExpiryDate;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;
  final String? avatarUrl;
  final VehicleModel? assignedVehicle;
  final bool isOnline;
  final double rating;
  final int completedTripsCount;
  final Map<String, bool> documentsUploaded;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.emergencyContact,
    required this.licenseNumber,
    required this.licenseExpiryDate,
    required this.verificationStatus,
    this.rejectionReason,
    this.avatarUrl,
    this.assignedVehicle,
    this.isOnline = false,
    this.rating = 4.9,
    this.completedTripsCount = 0,
    required this.documentsUploaded,
  });

  bool get canGoOnline =>
      verificationStatus.isApproved && (assignedVehicle?.isEligible ?? false);

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final Map<String, bool> docs = {};
    if (json['documents_uploaded'] != null && json['documents_uploaded'] is Map) {
      (json['documents_uploaded'] as Map).forEach((k, v) {
        docs[k.toString()] = v == true || v == 1 || v.toString() == 'true';
      });
    }

    final rawVehicle = json['assigned_vehicle'];
    final vehicleMap = rawVehicle != null && rawVehicle is Map
        ? Map<String, dynamic>.from(rawVehicle)
        : null;

    return DriverModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      emergencyContact: (json['emergency_contact'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      licenseExpiryDate: (json['license_expiry_date'] ?? '').toString(),
      verificationStatus: VerificationStatus.fromString(
        json['verification_status']?.toString(),
      ),
      rejectionReason: json['rejection_reason']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      assignedVehicle: vehicleMap != null ? VehicleModel.fromJson(vehicleMap) : null,
      isOnline: json['is_online'] == true ||
          json['is_online'] == 1 ||
          json['is_online'] == 'true',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      completedTripsCount: (json['completed_trips_count'] as num?)?.toInt() ??
          (json['total_trips'] as num?)?.toInt() ??
          0,
      documentsUploaded: docs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'emergency_contact': emergencyContact,
      'license_number': licenseNumber,
      'license_expiry_date': licenseExpiryDate,
      'verification_status': verificationStatus.name,
      'rejection_reason': rejectionReason,
      'avatar_url': avatarUrl,
      'assigned_vehicle': assignedVehicle?.toJson(),
      'is_online': isOnline,
      'rating': rating,
      'completed_trips_count': completedTripsCount,
      'documents_uploaded': documentsUploaded,
    };
  }

  DriverModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? emergencyContact,
    String? licenseNumber,
    String? licenseExpiryDate,
    VerificationStatus? verificationStatus,
    String? rejectionReason,
    String? avatarUrl,
    VehicleModel? assignedVehicle,
    bool? isOnline,
    double? rating,
    int? completedTripsCount,
    Map<String, bool>? documentsUploaded,
  }) {
    return DriverModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      assignedVehicle: assignedVehicle ?? this.assignedVehicle,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      completedTripsCount: completedTripsCount ?? this.completedTripsCount,
      documentsUploaded: documentsUploaded ?? this.documentsUploaded,
    );
  }
}
