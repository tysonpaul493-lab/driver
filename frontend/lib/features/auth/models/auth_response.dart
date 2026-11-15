import 'dart:convert';
import 'driver_model.dart';

/// Authentication response containing Sanctum token and Driver details
class AuthResponse {
  final String token;
  final String tokenType;
  final DriverModel driver;

  AuthResponse({
    required this.token,
    this.tokenType = 'Bearer',
    required this.driver,
  });

  factory AuthResponse.fromJson(dynamic raw) {
    dynamic json = raw;
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {}
    }
    final map = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    final rawDriver = map['driver'] ?? (map.containsKey('phone') ? map : null);
    final Map<String, dynamic> driverMap = rawDriver != null && rawDriver is Map
        ? Map<String, dynamic>.from(rawDriver)
        : <String, dynamic>{};

    return AuthResponse(
      token: (map['token'] ?? map['access_token'] ?? '').toString(),
      tokenType: (map['token_type'] ?? 'Bearer').toString(),
      driver: DriverModel.fromJson(driverMap),
    );
  }
}
