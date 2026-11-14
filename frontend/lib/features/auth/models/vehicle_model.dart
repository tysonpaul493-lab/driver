/// Vehicle types and equipment specifications for ambulances
enum VehicleType {
  bls('Basic Life Support (BLS)'),
  als('Advanced Life Support (ALS)'),
  ptv('Patient Transport Vehicle (PTV)'),
  nicu('Neonatal / Pediatric ICU');

  final String displayName;
  const VehicleType(this.displayName);

  static VehicleType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'als':
        return VehicleType.als;
      case 'ptv':
        return VehicleType.ptv;
      case 'nicu':
        return VehicleType.nicu;
      case 'bls':
      default:
        return VehicleType.bls;
    }
  }
}

/// Ambulance details, equipment inventory, and operational permit
class VehicleModel {
  final int? id;
  final String registrationNumber;
  final VehicleType vehicleType;
  final String makeModel;
  final int year;
  final List<String> equipmentList;
  final String operatorAffiliation; // Hospital or Fleet Operator name
  final String permitNumber;
  final String permitExpiryDate;
  final String insurancePolicyNumber;
  final String insuranceExpiryDate;
  final bool isEligible;

  VehicleModel({
    this.id,
    required this.registrationNumber,
    required this.vehicleType,
    required this.makeModel,
    required this.year,
    required this.equipmentList,
    required this.operatorAffiliation,
    required this.permitNumber,
    required this.permitExpiryDate,
    required this.insurancePolicyNumber,
    required this.insuranceExpiryDate,
    this.isEligible = true,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int?,
      registrationNumber: json['registration_number'] as String? ?? '',
      vehicleType: VehicleType.fromString(json['vehicle_type'] as String?),
      makeModel: json['make_model'] as String? ?? '',
      year: json['year'] as int? ?? 2024,
      equipmentList: json['equipment_list'] != null
          ? List<String>.from(json['equipment_list'] as List)
          : const <String>[],
      operatorAffiliation: json['operator_affiliation'] as String? ?? '',
      permitNumber: json['permit_number'] as String? ?? '',
      permitExpiryDate: json['permit_expiry_date'] as String? ?? '',
      insurancePolicyNumber: json['insurance_policy_number'] as String? ?? '',
      insuranceExpiryDate: json['insurance_expiry_date'] as String? ?? '',
      isEligible: json['is_eligible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registration_number': registrationNumber,
      'vehicle_type': vehicleType.name,
      'make_model': makeModel,
      'year': year,
      'equipment_list': equipmentList,
      'operator_affiliation': operatorAffiliation,
      'permit_number': permitNumber,
      'permit_expiry_date': permitExpiryDate,
      'insurance_policy_number': insurancePolicyNumber,
      'insurance_expiry_date': insuranceExpiryDate,
      'is_eligible': isEligible,
    };
  }

  VehicleModel copyWith({
    int? id,
    String? registrationNumber,
    VehicleType? vehicleType,
    String? makeModel,
    int? year,
    List<String>? equipmentList,
    String? operatorAffiliation,
    String? permitNumber,
    String? permitExpiryDate,
    String? insurancePolicyNumber,
    String? insuranceExpiryDate,
    bool? isEligible,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      makeModel: makeModel ?? this.makeModel,
      year: year ?? this.year,
      equipmentList: equipmentList ?? this.equipmentList,
      operatorAffiliation: operatorAffiliation ?? this.operatorAffiliation,
      permitNumber: permitNumber ?? this.permitNumber,
      permitExpiryDate: permitExpiryDate ?? this.permitExpiryDate,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      isEligible: isEligible ?? this.isEligible,
    );
  }
}
