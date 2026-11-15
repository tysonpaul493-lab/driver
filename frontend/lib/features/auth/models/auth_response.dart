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
    final json = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final rawDriver = json['driver'];
    final Map<String, dynamic> driverMap = rawDriver != null && rawDriver is Map
        ? Map<String, dynamic>.from(rawDriver)
        : <String, dynamic>{};

    return AuthResponse(
      token: (json['token'] ?? json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      driver: DriverModel.fromJson(driverMap),
    );
  }
}
