import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../services/driver_location_service.dart';

final locationServiceProvider = Provider<DriverLocationService>((ref) {
  final dio = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return DriverLocationService(dio, storage);
});

class DriverLocationState {
  final double? latitude;
  final double? longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final bool isGpsStale;
  final bool isTracking;
  final DateTime? lastUpdated;
  final String currentAddress;

  const DriverLocationState({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.accuracy = 0.0,
    this.heading = 0.0,
    this.speed = 0.0,
    this.isGpsStale = false,
    this.isTracking = false,
    this.lastUpdated,
    this.currentAddress = '',
  });

  DriverLocationState copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? heading,
    double? speed,
    bool? isGpsStale,
    bool? isTracking,
    DateTime? lastUpdated,
    String? currentAddress,
  }) {
    return DriverLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      isTracking: isTracking ?? this.isTracking,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentAddress: currentAddress ?? this.currentAddress,
    );
  }
}

class DriverLocationNotifier extends StateNotifier<DriverLocationState> {
  final DriverLocationService _service;
  DateTime? _lastGeocodeTime;
  double? _lastGeocodeLat;
  double? _lastGeocodeLng;
  bool _isGeocoding = false;

  DriverLocationNotifier(this._service) : super(const DriverLocationState()) {
    _initListener();
    refreshCurrentLocation();
  }

  static String resolveIndianAddress(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) {
      return 'Acquiring live GPS fix...';
    }
    return 'GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  /// Reverse geocode coordinates using live OpenStreetMap Nominatim with local fallback
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {'User-Agent': 'A2IEmergencyDriver/1.0'},
        ),
      );
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lng,
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final address = data is Map && data['address'] is Map
            ? Map<String, dynamic>.from(data['address'])
            : null;
        if (address != null) {
          final road =
              address['road'] ??
              address['pedestrian'] ??
              address['neighbourhood'] ??
              address['suburb'] ??
              '';
          final city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              '';
          final state = address['state'] ?? '';
          final parts = [
            road,
            city,
            state,
          ].where((s) => s.toString().trim().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final chunks = displayName.split(',');
          return chunks.take(3).join(',').trim();
        }
      }
    } catch (_) {}
    return resolveIndianAddress(lat, lng);
  }

  void _initListener() {
    _service.onTelemetryUpdated.listen((telemetry) {
      if (!mounted) return;
      state = state.copyWith(
        latitude: telemetry.latitude,
        longitude: telemetry.longitude,
        accuracy: telemetry.accuracy,
        heading: telemetry.heading,
        speed: telemetry.speed,
        isGpsStale: telemetry.isGpsStale,
        isTracking: _service.isTracking,
        lastUpdated: telemetry.timestamp,
        currentAddress: _lastGeocodeTime == null
            ? resolveIndianAddress(telemetry.latitude, telemetry.longitude)
            : state.currentAddress,
      );
      _refreshAddressInBackground(telemetry.latitude, telemetry.longitude);
    });
  }

  Future<void> _refreshAddressInBackground(
    double lat,
    double lng, {
    bool force = false,
  }) async {
    if (_isGeocoding) return;
    final now = DateTime.now();
    if (!force &&
        _lastGeocodeTime != null &&
        _lastGeocodeLat != null &&
        _lastGeocodeLng != null &&
        now.difference(_lastGeocodeTime!).inSeconds < 20 &&
        (lat - _lastGeocodeLat!).abs() < 0.001 &&
        (lng - _lastGeocodeLng!).abs() < 0.001) {
      return;
    }

    _isGeocoding = true;
    try {
      final addr = await reverseGeocode(lat, lng);
      _lastGeocodeTime = DateTime.now();
      _lastGeocodeLat = lat;
      _lastGeocodeLng = lng;
      if (mounted) {
        state = state.copyWith(currentAddress: addr);
      }
    } finally {
      _isGeocoding = false;
    }
  }

  Future<void> startTracking({String? bookingReference}) async {
    await _service.startTracking(bookingReference: bookingReference);
    if (mounted) {
      state = state.copyWith(isTracking: true);
    }
  }

  Future<void> stopTracking() async {
    await _service.stopTracking();
    if (mounted) {
      state = state.copyWith(isTracking: false);
    }
  }

  Future<void> refreshCurrentLocation() async {
    final pos = await _service.getCurrentPosition();
    if (pos != null && mounted) {
      final firstResolve = _lastGeocodeTime == null;
      state = state.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        heading: pos.heading,
        speed: pos.speed,
        lastUpdated: pos.timestamp,
        currentAddress: firstResolve
            ? resolveIndianAddress(pos.latitude, pos.longitude)
            : state.currentAddress,
      );
      await _refreshAddressInBackground(
        pos.latitude,
        pos.longitude,
        force: firstResolve,
      );
    }
  }
}

final driverLocationProvider =
    StateNotifierProvider<DriverLocationNotifier, DriverLocationState>((ref) {
      final service = ref.watch(locationServiceProvider);
      return DriverLocationNotifier(service);
    });
