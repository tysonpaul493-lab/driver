import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

/// Secure Storage and persistent preferences service
class SecureStorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  SecureStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Sanctum Token Management
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: StorageKeys.authToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: StorageKeys.authToken);
  }

  Future<void> deleteAuthToken() async {
    await _secureStorage.delete(key: StorageKeys.authToken);
  }

  // Driver ID
  Future<void> saveDriverId(int id) async {
    await init();
    await _prefs?.setInt(StorageKeys.driverId, id);
  }

  Future<int?> getDriverId() async {
    await init();
    return _prefs?.getInt(StorageKeys.driverId);
  }

  // Driver Profile Cache
  Future<void> saveDriverProfile(Map<String, dynamic> profile) async {
    await init();
    await _prefs?.setString(StorageKeys.driverProfile, jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> getDriverProfile() async {
    await init();
    final data = _prefs?.getString(StorageKeys.driverProfile);
    if (data == null) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Online Status
  Future<void> setOnlineStatus(bool isOnline) async {
    await init();
    await _prefs?.setBool(StorageKeys.isOnline, isOnline);
  }

  Future<bool> getOnlineStatus() async {
    await init();
    return _prefs?.getBool(StorageKeys.isOnline) ?? false;
  }

  // Active Booking ID (Crash Recovery)
  Future<void> setActiveBookingId(String? bookingId) async {
    await init();
    if (bookingId == null) {
      await _prefs?.remove(StorageKeys.activeBookingId);
    } else {
      await _prefs?.setString(StorageKeys.activeBookingId, bookingId);
    }
  }

  Future<String?> getActiveBookingId() async {
    await init();
    return _prefs?.getString(StorageKeys.activeBookingId);
  }

  // Custom API Base URL
  Future<void> setCustomApiUrl(String? url) async {
    await init();
    if (url == null || url.isEmpty) {
      await _prefs?.remove(StorageKeys.customApiUrl);
    } else {
      await _prefs?.setString(StorageKeys.customApiUrl, url);
    }
  }

  Future<String?> getCustomApiUrl() async {
    await init();
    return _prefs?.getString(StorageKeys.customApiUrl);
  }

  // Registered Driver Profiles by Phone (Persistent Registration)
  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<void> saveRegisteredDriverByPhone(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await init();
    final clean = _normalizePhone(phone);
    final rawDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = jsonEncode(profile);
    if (clean.isNotEmpty) {
      await _prefs?.setString('reg_driver_$clean', encoded);
    }
    if (rawDigits.isNotEmpty && rawDigits != clean) {
      await _prefs?.setString('reg_driver_$rawDigits', encoded);
    }
    // Also store as last registered driver and main driver profile
    await _prefs?.setString('last_reg_driver', encoded);
    await saveDriverProfile(profile);
  }

  Future<Map<String, dynamic>?> getRegisteredDriverByPhone(String phone) async {
    await init();
    final clean = _normalizePhone(phone);
    final rawDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isNotEmpty) {
      final data = _prefs?.getString('reg_driver_$clean');
      if (data != null) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    if (rawDigits.isNotEmpty) {
      final data = _prefs?.getString('reg_driver_$rawDigits');
      if (data != null) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    // Fallback to last registered driver if available
    final lastData = _prefs?.getString('last_reg_driver');
    if (lastData != null) {
      try {
        final decoded = jsonDecode(lastData);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    // Fallback to currently cached driver profile
    final currentProfile = await getDriverProfile();
    if (currentProfile != null) {
      return currentProfile;
    }
    return null;
  }

  // Uploaded Document Image Paths
  Future<void> saveDocumentImagePath(String docKey, String path) async {
    await init();
    await _prefs?.setString('doc_path_$docKey', path);
  }

  Future<String?> getDocumentImagePath(String docKey) async {
    await init();
    return _prefs?.getString('doc_path_$docKey');
  }

  Future<Map<String, String>> getAllDocumentImagePaths() async {
    await init();
    final result = <String, String>{};
    final keys = _prefs?.getKeys() ?? {};
    for (final k in keys) {
      if (k.startsWith('doc_path_')) {
        final docKey = k.replaceFirst('doc_path_', '');
        final val = _prefs?.getString(k);
        if (val != null && val.isNotEmpty) {
          result[docKey] = val;
        }
      }
    }
    return result;
  }

  Future<void> saveCompletedTrip(Map<String, dynamic> trip) async {
    await init();
    final existing = await getCompletedTrips();
    final ref = trip['booking_reference']?.toString();
    final id = trip['id']?.toString();
    existing.removeWhere(
      (t) =>
          (ref != null &&
              ref.isNotEmpty &&
              t['booking_reference']?.toString() == ref) ||
          (id != null && id.isNotEmpty && t['id']?.toString() == id),
    );
    existing.insert(0, trip);
    await _prefs?.setString('completed_trips_history', jsonEncode(existing));
  }

  Future<void> updateCompletedTrip(Map<String, dynamic> updatedTrip) async {
    await init();
    final existing = await getCompletedTrips();
    final index = existing.indexWhere(
      (t) =>
          (updatedTrip['booking_reference'] != null &&
              t['booking_reference'] == updatedTrip['booking_reference']) ||
          (updatedTrip['id'] != null && t['id'] == updatedTrip['id']),
    );
    if (index >= 0) {
      existing[index] = updatedTrip;
    } else {
      existing.insert(0, updatedTrip);
    }
    await _prefs?.setString('completed_trips_history', jsonEncode(existing));
  }

  Future<List<Map<String, dynamic>>> getCompletedTrips() async {
    await init();
    final data = _prefs?.getString('completed_trips_history');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      final seen = <String>{};
      final result = <Map<String, dynamic>>[];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        final ref = map['booking_reference']?.toString() ?? '';
        final id = map['id']?.toString() ?? '';
        final key = ref.isNotEmpty ? ref : id;
        if (key.isEmpty || seen.add(key)) {
          result.add(map);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // Synced Driver Details for Emergency User App
  Future<void> saveAcceptedDriverInfo(Map<String, dynamic> info) async {
    await init();
    await _prefs?.setString('last_accepted_driver_dispatch', jsonEncode(info));
  }

  Future<Map<String, dynamic>?> getAcceptedDriverInfo() async {
    await init();
    final data = _prefs?.getString('last_accepted_driver_dispatch');
    if (data == null) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Clear session data on logout (preserves registered profiles and uploaded docs)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await init();
    await _prefs?.remove(StorageKeys.driverId);
    await _prefs?.remove(StorageKeys.driverProfile);
    await _prefs?.remove(StorageKeys.isOnline);
    await _prefs?.remove(StorageKeys.activeBookingId);
  }
}
