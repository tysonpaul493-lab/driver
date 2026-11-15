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

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      driver: json['driver'] != null && json['driver'] is Map
          ? DriverModel.fromJson(Map<String, dynamic>.from(json['driver'] as Map))
          : DriverModel.fromJson({}),
    );
  }
}
