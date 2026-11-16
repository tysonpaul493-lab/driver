import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/auth_response.dart';
import '../models/driver_model.dart';

/// Repository for driver authentication, profile, registration, and documents
class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRepository(this._dioClient, this._storageService);

  /// Request phone OTP for login via configured SMS gateway
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _dioClient.post(
      ApiConstants.sendOtp,
      data: {'phone': phone},
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final map = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
    return map;
  }

  /// Check if a phone number is registered on the dispatch server
  Future<bool> checkPhoneRegistered(String phone) async {
    final response = await _dioClient.post(
      '/driver/auth/check-phone',
      data: {'phone': phone},
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
    return data['is_registered'] == true || data['registered'] == true;
  }

  /// Verify OTP and store Sanctum token
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    final response = await _dioClient.post(
      ApiConstants.verifyOtp,
      data: {'phone': phone, 'otp': otp, 'device_name': 'Driver Mobile App'},
    );

    final authResponse = AuthResponse.fromJson(response);

    // Save token and profile to secure storage
    await _storageService.saveAuthToken(authResponse.token);
    await _storageService.saveDriverId(authResponse.driver.id);
    await _storageService.saveDriverProfile(authResponse.driver.toJson());
    await _storageService.setOnlineStatus(authResponse.driver.isOnline);

    return authResponse;
  }

  /// Sign in using mobile number and driver account password
  Future<AuthResponse> loginWithPassword(String phone, String password) async {
    final response = await _dioClient.post(
      ApiConstants.loginWithPassword,
      data: {
        'phone': phone,
        'password': password,
        'device_name': 'Driver Mobile App',
      },
    );

    dynamic parsed = response;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {}
    }

    if (parsed is Map && parsed['status'] == 'error') {
      throw ApiException(
        message: parsed['message']?.toString() ?? 'Invalid mobile number or password.',
      );
    }

    final authResponse = AuthResponse.fromJson(parsed);
    await _storageService.saveAuthToken(authResponse.token);
    await _storageService.saveDriverId(authResponse.driver.id);
    await _storageService.saveDriverProfile(authResponse.driver.toJson());
    await _storageService.setOnlineStatus(authResponse.driver.isOnline);

    return authResponse;
  }

  /// Reset password directly for driver account
  Future<AuthResponse> resetPassword(
    String phone,
    String newPassword,
    String confirmPassword,
  ) async {
    final response = await _dioClient.post(
      ApiConstants.resetPassword,
      data: {
        'phone': phone,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );

    final authResponse = AuthResponse.fromJson(response);
    await _storageService.saveAuthToken(authResponse.token);
    await _storageService.saveDriverId(authResponse.driver.id);
    await _storageService.saveDriverProfile(authResponse.driver.toJson());
    await _storageService.setOnlineStatus(authResponse.driver.isOnline);

    return authResponse;
  }

  /// Register a new ambulance driver with vehicle specifications and password
  Future<AuthResponse> registerDriver({
    required String name,
    required String phone,
    String? password,
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
        if (password != null && password.isNotEmpty) 'password': password,
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

    final authResponse = AuthResponse.fromJson(response);
    // Registration must not set an active login session token: driver must log in with their ID and password
    await _storageService.deleteAuthToken();
    await _storageService.saveRegisteredDriverByPhone(
      phone,
      authResponse.driver.toJson(),
    );

    return authResponse;
  }

  /// Upload compliance and license documents to dispatch backend
  Future<Map<String, dynamic>> uploadDocument({
    required File file,
    required String documentType,
    String? expiryDate,
  }) async {
    final response = await _dioClient.uploadFile(
      ApiConstants.uploadDocuments,
      file: file,
      fileField: 'document',
      extraFields: {'document_type': documentType, 'expiry_date': ?expiryDate},
    );
    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
  }

  /// Upload compliance documents from raw bytes (Web-safe)
  Future<Map<String, dynamic>> uploadDocumentBytes({
    required List<int> bytes,
    required String fileName,
    required String documentType,
    String? expiryDate,
  }) async {
    final response = await _dioClient.uploadFileBytes(
      ApiConstants.uploadDocuments,
      bytes: bytes,
      fileName: fileName,
      fileField: 'document',
      extraFields: {'document_type': documentType, 'expiry_date': ?expiryDate},
    );
    return response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{};
  }

  /// Update driver and ambulance profile fields on dispatch backend
  Future<DriverModel> updateProfile({
    required String name,
    required String email,
    required String emergencyContact,
    required String licenseNumber,
    required String registrationNumber,
    required String vehicleType,
    required String makeModel,
    required String operatorAffiliation,
  }) async {
    final response = await _dioClient.put(
      ApiConstants.profile,
      data: {
        'name': name,
        'email': email,
        'emergency_contact': emergencyContact,
        'license_number': licenseNumber,
        'ambulance': {
          'registration_number': registrationNumber,
          'vehicle_type': vehicleType,
          'make_model': makeModel,
          'operator_affiliation': operatorAffiliation,
        },
      },
    );
    final rawDriver = response is Map ? (response['driver'] ?? response) : null;
    final driverMap = rawDriver is Map
        ? Map<String, dynamic>.from(rawDriver)
        : <String, dynamic>{};
    final driver = DriverModel.fromJson(driverMap);
    await _storageService.saveDriverProfile(driver.toJson());
    return driver;
  }

  /// Fetch updated driver profile and vehicle info
  Future<DriverModel> getProfile() async {
    final response = await _dioClient.get(ApiConstants.profile);
    final rawDriver = response is Map ? (response['driver'] ?? response) : null;
    final driverMap = rawDriver is Map
        ? Map<String, dynamic>.from(rawDriver)
        : <String, dynamic>{};
    final driver = DriverModel.fromJson(driverMap);
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
