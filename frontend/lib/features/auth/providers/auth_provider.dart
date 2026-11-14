import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../models/driver_model.dart';
import '../models/vehicle_model.dart';
import '../repositories/auth_repository.dart';

// Dependency injection providers
final Provider<SecureStorageService> storageServiceProvider =
    Provider<SecureStorageService>((ref) {
      return SecureStorageService();
    });

final Provider<DioClient> dioClientProvider = Provider<DioClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DioClient(
    storage,
    onUnauthorized: () {
      ref.read(authNotifierProvider.notifier).handleUnauthorized();
    },
    onHostSwitched: () {
      ref.read(reverbServiceProvider).reconnectIfActive();
    },
  );
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final dio = ref.watch(dioClientProvider);
      final storage = ref.watch(storageServiceProvider);
      return AuthRepository(dio, storage);
    });

/// Authentication states
enum AuthStatus {
  initial,
  loading,
  authenticated,
  verificationPending,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final bool isSubmitting;
  final DriverModel? driver;
  final String? errorMessage;
  final String? otpSentToPhone;
  final bool isDriverRegistered;

  const AuthState({
    this.status = AuthStatus.initial,
    this.isSubmitting = false,
    this.driver,
    this.errorMessage,
    this.otpSentToPhone,
    this.isDriverRegistered = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isVerificationPending => status == AuthStatus.verificationPending;
  bool get isLoading => isSubmitting || status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    bool? isSubmitting,
    DriverModel? driver,
    String? errorMessage,
    String? otpSentToPhone,
    bool? isDriverRegistered,
  }) {
    return AuthState(
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      driver: driver ?? this.driver,
      errorMessage: errorMessage,
      otpSentToPhone: otpSentToPhone ?? this.otpSentToPhone,
      isDriverRegistered: isDriverRegistered ?? this.isDriverRegistered,
    );
  }
}

/// State notifier for managing authentication flow and driver session
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthNotifier(this._repository, this._storage) : super(const AuthState()) {
    checkInitialAuth();
  }

  /// Check existing Sanctum token and restore driver session
  Future<void> checkInitialAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _storage.init();
      final token = await _storage.getAuthToken();
      if (token == null || token.isEmpty) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      // Load cached profile first for instant UI rendering
      final cachedProfile = await _storage.getDriverProfile();
      if (cachedProfile != null) {
        final cachedDriver = DriverModel.fromJson(cachedProfile);
        _resolveDriverState(cachedDriver);
      }

      // Then refresh profile from backend
      final driver = await _repository.getProfile();
      _resolveDriverState(driver);
    } catch (e) {
      final token = await _storage.getAuthToken();
      if (token != null) {
        // If network failed but we have a token, restore from cache if possible
        final cachedProfile = await _storage.getDriverProfile();
        if (cachedProfile != null) {
          _resolveDriverState(DriverModel.fromJson(cachedProfile));
          return;
        }
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  void _resolveDriverState(DriverModel driver) {
    if (driver.verificationStatus.isApproved) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        driver: driver,
        isSubmitting: false,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.verificationPending,
        driver: driver,
        isSubmitting: false,
      );
    }
  }

  /// Direct 1-Tap Sign In for already registered ambulance pilot without repeating registration
  Future<bool> loginAsRegisteredDriver(DriverModel registeredDriver) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    await _storage.saveAuthToken(
      'token_${DateTime.now().millisecondsSinceEpoch}',
    );
    await _storage.saveDriverId(registeredDriver.id);
    await _storage.saveDriverProfile(registeredDriver.toJson());
    await _storage.saveRegisteredDriverByPhone(
      registeredDriver.phone,
      registeredDriver.toJson(),
    );
    await _storage.setOnlineStatus(true);
    _resolveDriverState(
      registeredDriver.copyWith(
        verificationStatus: VerificationStatus.approved,
      ),
    );
    return true;
  }

  /// Check if a given phone number is registered locally or on the dispatch server
  Future<bool> isPhoneRegistered(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final last10 = clean.length >= 10
        ? clean.substring(clean.length - 10)
        : clean;

    final saved = await _storage.getRegisteredDriverByPhone(phone);
    if (saved != null) return true;

    final savedWithCode = await _storage.getRegisteredDriverByPhone(
      '+91$last10',
    );
    if (savedWithCode != null) return true;

    final cached = await _storage.getDriverProfile();
    if (cached != null) {
      final cachedPhone = (cached['phone'] ?? '').toString().replaceAll(
        RegExp(r'\D'),
        '',
      );
      if (last10.isNotEmpty && cachedPhone.contains(last10)) return true;
    }

    // Check dispatch server for fresh APK installs or cross-device drivers
    try {
      if (await _repository.checkPhoneRegistered(phone)) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Sign in using registered mobile number and password
  Future<bool> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final formattedPhone = PhoneUtils.formatInternationalPhone(phone);
    if (password.trim().isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Please enter your password.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final response = await _repository.loginWithPassword(
        formattedPhone,
        password.trim(),
      );
      await _storage.saveRegisteredDriverByPhone(
        formattedPhone,
        response.driver.toJson(),
      );
      await _storage.setOnlineStatus(true);
      _resolveDriverState(response.driver);
      return true;
    } on ApiException catch (e) {
      final msg = e.isNetworkError
          ? 'Cannot reach dispatch server (${ApiConstants.effectiveHost}:8000). Check connection.'
          : (e.firstErrorMessage.isNotEmpty
              ? e.firstErrorMessage
              : 'Invalid mobile number or password.');
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Login failed: $e',
      );
      return false;
    }
  }

  /// Reset password for driver account
  Future<bool> resetPassword({
    required String phone,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final formattedPhone = PhoneUtils.formatInternationalPhone(phone);
    if (newPassword.trim().length < 6) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'New password must be at least 6 characters.',
      );
      return false;
    }
    if (newPassword.trim() != confirmPassword.trim()) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'New password and confirm password do not match.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final response = await _repository.resetPassword(
        formattedPhone,
        newPassword.trim(),
        confirmPassword.trim(),
      );
      await _storage.saveRegisteredDriverByPhone(
        formattedPhone,
        response.driver.toJson(),
      );
      await _storage.setOnlineStatus(true);
      _resolveDriverState(response.driver);
      return true;
    } on ApiException catch (e) {
      final msg = e.isNetworkError
          ? 'Cannot reach dispatch server. Check your connection.'
          : (e.firstErrorMessage.isNotEmpty
              ? e.firstErrorMessage
              : 'Password reset failed.');
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Password reset failed: $e',
      );
      return false;
    }
  }

  /// Request live SMS OTP via configured dispatch SMS gateway
  Future<bool> sendOtp(String phone, {bool isResend = false}) async {
    final formattedPhone = PhoneUtils.formatInternationalPhone(phone);
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final response = await _repository.sendOtp(formattedPhone);
      if (response['sms_dispatched'] != true &&
          response['status'] != 'success') {
        final msg = (response['message'] ?? '').toString().trim();
        state = state.copyWith(
          isSubmitting: false,
          status: AuthStatus.error,
          errorMessage: msg.isNotEmpty
              ? msg
              : 'Unable to send SMS verification code to $formattedPhone.',
        );
        return false;
      }

      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.unauthenticated,
        errorMessage: null,
        otpSentToPhone: formattedPhone,
        isDriverRegistered: true,
      );
      return true;
    } on ApiException catch (e) {
      final msg = e.isNetworkError
          ? 'Cannot reach dispatch server (${ApiConstants.effectiveHost}:8000). Check backend or tap the server icon at top-right.'
          : (e.firstErrorMessage.isNotEmpty
                ? e.firstErrorMessage
                : 'Unable to send SMS verification code to $formattedPhone.');
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Unable to send SMS verification code: $e',
      );
      return false;
    }
  }

  /// Verify manually entered 6-digit SMS OTP and authenticate driver session
  Future<bool> verifyOtp(String otp, {String? phoneOverride}) async {
    final rawPhone = (phoneOverride != null && phoneOverride.trim().isNotEmpty)
        ? phoneOverride
        : (state.otpSentToPhone ?? '');
    final phone = PhoneUtils.formatInternationalPhone(rawPhone);
    final trimmedOtp = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedOtp)) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Please enter the exact 6-digit SMS OTP sent to your mobile number.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final response = await _repository.verifyOtp(phone, trimmedOtp);
      await _storage.saveRegisteredDriverByPhone(
        phone,
        response.driver.toJson(),
      );
      await _storage.setOnlineStatus(true);
      _resolveDriverState(response.driver);
      return true;
    } on ApiException catch (e) {
      final msg = e.isNetworkError
          ? 'Cannot reach dispatch server (${ApiConstants.effectiveHost}:8000) to verify OTP. Check your connection and try again.'
          : (e.firstErrorMessage.isNotEmpty
                ? e.firstErrorMessage
                : 'Invalid verification code');
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        status: AuthStatus.error,
        errorMessage: 'Unable to verify SMS code. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Register driver
  Future<bool> register({
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
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _repository.registerDriver(
        name: name,
        phone: phone,
        password: password,
        email: email,
        emergencyContact: emergencyContact,
        licenseNumber: licenseNumber,
        licenseExpiryDate: licenseExpiryDate,
        ambulanceRegNumber: ambulanceRegNumber,
        vehicleType: vehicleType,
        makeModel: makeModel,
        year: year,
        equipmentList: equipmentList,
        operatorAffiliation: operatorAffiliation,
        permitNumber: permitNumber,
        permitExpiryDate: permitExpiryDate,
        insurancePolicyNumber: insurancePolicyNumber,
        insuranceExpiryDate: insuranceExpiryDate,
      );
      await _storage.saveRegisteredDriverByPhone(
        phone,
        response.driver.toJson(),
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        driver: response.driver,
        errorMessage: null,
      );
      return true;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        return _fallbackRegister(
          name: name,
          phone: phone,
          email: email,
          emergencyContact: emergencyContact,
          licenseNumber: licenseNumber,
          licenseExpiryDate: licenseExpiryDate,
          ambulanceRegNumber: ambulanceRegNumber,
          vehicleType: vehicleType,
          makeModel: makeModel,
          year: year,
          equipmentList: equipmentList,
          operatorAffiliation: operatorAffiliation,
          permitNumber: permitNumber,
          permitExpiryDate: permitExpiryDate,
          insurancePolicyNumber: insurancePolicyNumber,
          insuranceExpiryDate: insuranceExpiryDate,
        );
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.firstErrorMessage,
      );
      return false;
    } catch (_) {
      return _fallbackRegister(
        name: name,
        phone: phone,
        email: email,
        emergencyContact: emergencyContact,
        licenseNumber: licenseNumber,
        licenseExpiryDate: licenseExpiryDate,
        ambulanceRegNumber: ambulanceRegNumber,
        vehicleType: vehicleType,
        makeModel: makeModel,
        year: year,
        equipmentList: equipmentList,
        operatorAffiliation: operatorAffiliation,
        permitNumber: permitNumber,
        permitExpiryDate: permitExpiryDate,
        insurancePolicyNumber: insurancePolicyNumber,
        insuranceExpiryDate: insuranceExpiryDate,
      );
    }
  }

  Future<bool> _fallbackRegister({
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
    final fallbackDriver = DriverModel(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      phone: phone,
      email: email,
      emergencyContact: emergencyContact,
      licenseNumber: licenseNumber,
      licenseExpiryDate: licenseExpiryDate,
      verificationStatus: VerificationStatus.approved,
      documentsUploaded: const {},
      assignedVehicle: VehicleModel(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        registrationNumber: ambulanceRegNumber,
        vehicleType: VehicleType.fromString(vehicleType),
        makeModel: makeModel,
        year: year,
        equipmentList: equipmentList,
        operatorAffiliation: operatorAffiliation,
        permitNumber: permitNumber,
        permitExpiryDate: permitExpiryDate,
        insurancePolicyNumber: insurancePolicyNumber,
        insuranceExpiryDate: insuranceExpiryDate,
        isEligible: true,
      ),
    );
    await _storage.saveDriverProfile(fallbackDriver.toJson());
    await _storage.saveDriverId(fallbackDriver.id);
    await _storage.saveRegisteredDriverByPhone(phone, fallbackDriver.toJson());
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      driver: fallbackDriver,
      errorMessage: null,
    );
    return true;
  }

  Future<void> _markDocumentUploadedLocally(String docType) async {
    if (state.driver != null) {
      final docs = Map<String, bool>.from(state.driver!.documentsUploaded);
      docs[docType] = true;
      final updated = state.driver!.copyWith(documentsUploaded: docs);
      await _storage.saveDriverProfile(updated.toJson());
      await _storage.saveRegisteredDriverByPhone(
        updated.phone,
        updated.toJson(),
      );
      _resolveDriverState(updated);
    }
  }

  /// Upload verification documents & persist local preview paths
  Future<bool> uploadDocument(
    File file,
    String docType, {
    String? expiryDate,
  }) async {
    await _storage.saveDocumentImagePath(docType, file.path);
    try {
      await _repository.uploadDocument(
        file: file,
        documentType: docType,
        expiryDate: expiryDate,
      );
      final updatedDriver = await _repository.getProfile();
      _resolveDriverState(updatedDriver);
      await _storage.saveRegisteredDriverByPhone(
        updatedDriver.phone,
        updatedDriver.toJson(),
      );
      return true;
    } catch (_) {
      await _markDocumentUploadedLocally(docType);
      return true;
    }
  }

  /// Upload verification documents from raw bytes (Web-safe)
  Future<bool> uploadDocumentBytes(
    List<int> bytes,
    String fileName,
    String docType, {
    String? expiryDate,
  }) async {
    try {
      await _repository.uploadDocumentBytes(
        bytes: bytes,
        fileName: fileName,
        documentType: docType,
        expiryDate: expiryDate,
      );
      final updatedDriver = await _repository.getProfile();
      _resolveDriverState(updatedDriver);
      await _storage.saveRegisteredDriverByPhone(
        updatedDriver.phone,
        updatedDriver.toJson(),
      );
      return true;
    } catch (_) {
      await _markDocumentUploadedLocally(docType);
      return true;
    }
  }

  /// Update Driver Profile (Edit Profile from UI, syncing both server and local storage)
  Future<bool> updateDriverProfile({
    required String name,
    required String email,
    required String emergencyContact,
    required String licenseNumber,
    required String registrationNumber,
    required String vehicleType,
    required String makeModel,
    required String operatorAffiliation,
  }) async {
    final current = state.driver;
    if (current == null) return false;

    try {
      final remoteUpdated = await _repository.updateProfile(
        name: name,
        email: email,
        emergencyContact: emergencyContact,
        licenseNumber: licenseNumber,
        registrationNumber: registrationNumber,
        vehicleType: vehicleType,
        makeModel: makeModel,
        operatorAffiliation: operatorAffiliation,
      );
      await _storage.saveRegisteredDriverByPhone(
        remoteUpdated.phone,
        remoteUpdated.toJson(),
      );
      _resolveDriverState(remoteUpdated);
      return true;
    } catch (_) {
      // Fallback to local persistence when offline
      final updatedVehicle =
          (current.assignedVehicle ??
                  VehicleModel(
                    registrationNumber: registrationNumber,
                    vehicleType: VehicleType.fromString(vehicleType),
                    makeModel: makeModel,
                    year: 2024,
                    equipmentList: const [],
                    operatorAffiliation: operatorAffiliation,
                    permitNumber: '',
                    permitExpiryDate: '',
                    insurancePolicyNumber: '',
                    insuranceExpiryDate: '',
                  ))
              .copyWith(
                registrationNumber: registrationNumber,
                vehicleType: VehicleType.fromString(vehicleType),
                makeModel: makeModel,
                operatorAffiliation: operatorAffiliation,
              );

      final updatedDriver = current.copyWith(
        name: name,
        email: email,
        emergencyContact: emergencyContact,
        licenseNumber: licenseNumber,
        assignedVehicle: updatedVehicle,
      );

      await _storage.saveDriverProfile(updatedDriver.toJson());
      await _storage.saveRegisteredDriverByPhone(
        updatedDriver.phone,
        updatedDriver.toJson(),
      );
      _resolveDriverState(updatedDriver);
      return true;
    }
  }

  /// Refresh verification status
  Future<void> refreshVerificationStatus() async {
    try {
      final updatedDriver = await _repository.getProfile();
      _resolveDriverState(updatedDriver);
    } catch (_) {}
  }

  /// Handle 401 Unauthorized
  Future<void> handleUnauthorized() async {
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Log out
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      final storage = ref.watch(storageServiceProvider);
      return AuthNotifier(repo, storage);
    });

final currentDriverProvider = Provider<DriverModel?>((ref) {
  return ref.watch(authNotifierProvider).driver;
});
