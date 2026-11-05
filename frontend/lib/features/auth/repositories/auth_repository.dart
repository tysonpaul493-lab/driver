import 'dart:io';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/auth_response.dart';
import '../models/driver_model.dart';

/// Repository for driver authentication, profile, registration, and documents
class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRepository(this._dioClient, this._storageService);

  /// Request phone OTP for login
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _dioClient.post(
      ApiConstants.sendOtp,
      data: {'phone': phone},
    );
    return response as Map<String, dynamic>;
  }

  /// Verify OTP and store Sanctum token
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    final response = await _dioClient.post(
      ApiConstants.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
        'device_name': 'Driver Mobile App',
      },
    );

    final authResponse = AuthResponse.fromJson(response as Map<String, dynamic>);
    
    // Save token and profile to secure storage
    await _storageService.saveAuthToken(authResponse.token);
    await _storageService.saveDriverId(authResponse.driver.id);
    await _storageService.saveDriverProfile(authResponse.driver.toJson());
    await _storageService.setOnlineStatus(authResponse.driver.isOnline);

    return authResponse;
  }

  /// Register a new ambulance driver with vehicle specifications
  Future<AuthResponse> registerDriver({
    required String name,
    required String phone,
    required String email,
    required String emergencyContact,
    required String licenseNumber,
    required String licenseExpiryDate,
    required String ambulanceRegNumber,
    required String vehicleType,
    required String makeModel,
    required int year,
    required List<String> equipmentList,
    required String operatorAffiliation,
    required String permitNumber,
    required String permitExpiryDate,
    required String insurancePolicyNumber,
    required String insuranceExpiryDate,
  }) async {
    final response = await _dioClient.post(
      ApiConstants.register,
      data: {
        'name': name,
        'phone': phone,
        'email': email,
        'emergency_contact': emergencyContact,
        'license_number': licenseNumber,
        'license_expiry_date': licenseExpiryDate,
        'ambulance': {
          'registration_number': ambulanceRegNumber,
          'vehicle_type': vehicleType,
          'make_model': makeModel,
          'year': year,
          'equipment_list': equipmentList,
          'operator_affiliation': operatorAffiliation,
          'permit_number': permitNumber,
          'permit_expiry_date': permitExpiryDate,
          'insurance_policy_number': insurancePolicyNumber,
          'insurance_expiry_date': insuranceExpiryDate,
        },
      },
    );

    final authResponse = AuthResponse.fromJson(response as Map<String, dynamic>);
    await _storageService.saveAuthToken(authResponse.token);
    await _storageService.saveDriverId(authResponse.driver.id);
    await _storageService.saveDriverProfile(authResponse.driver.toJson());

    return authResponse;
  }

  /// Upload compliance and license documents to Laravel backend
  Future<Map<String, dynamic>> uploadDocument({
    required File file,
    required String documentType,
    String? expiryDate,
  }) async {
    final response = await _dioClient.uploadFile(
      ApiConstants.uploadDocuments,
      file: file,
      fileField: 'document',
      extraFields: {
        'document_type': documentType,
        'expiry_date': ?expiryDate,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// Fetch updated driver profile and vehicle info
  Future<DriverModel> getProfile() async {
    final response = await _dioClient.get(ApiConstants.profile);
    final driver = DriverModel.fromJson(response['driver'] ?? response);
    await _storageService.saveDriverProfile(driver.toJson());
    return driver;
  }

  /// Check verification status from admin review
  Future<VerificationStatus> checkVerificationStatus() async {
    final response = await _dioClient.get(ApiConstants.verificationStatus);
    final statusStr = response['status'] as String?;
    return VerificationStatus.fromString(statusStr);
  }

  /// Log out driver, revoke Sanctum token, and clear storage
  Future<void> logout() async {
    try {
      await _dioClient.post(ApiConstants.logout);
    } catch (_) {}
    await _storageService.clearAll();
  }
}
