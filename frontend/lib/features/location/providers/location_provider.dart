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
    this.latitude = 12.9716, // India Standard (Bengaluru Center)
    this.longitude = 77.5946,
    this.accuracy = 5.0,
    this.heading = 0.0,
    this.speed = 0.0,
    this.isGpsStale = false,
    this.isTracking = false,
    this.lastUpdated,
    this.currentAddress = 'MG Road, Central Emergency Zone, Bengaluru',
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
    // Karnataka / Bengaluru Sector
    if (lat >= 12.75 && lat <= 13.30 && lng >= 77.35 && lng <= 77.85) {
      if (lat >= 12.96 && lat <= 13.00 && lng >= 77.58 && lng <= 77.64) {
        return 'MG Road & Brigade Junction, Central Bengaluru, Karnataka';
      } else if (lat < 12.94) {
        return 'Electronic City Phase 1, Bengaluru, Karnataka';
      } else if (lat > 13.02) {
        return 'Hebbal Flyover & Bellary Road, Bengaluru, Karnataka';
      } else if (lng < 77.56) {
        return 'Malleshwaram 8th Cross, Bengaluru, Karnataka';
      } else {
        return 'Indiranagar 100ft Road, Bengaluru, Karnataka';
      }
    }
    // Tamil Nadu / Coimbatore Sector
    else if (lat >= 10.75 && lat <= 11.35 && lng >= 76.75 && lng <= 77.25) {
      if (lat >= 10.98 && lat <= 11.05 && lng >= 76.92 && lng <= 77.02) {
        return 'Gandhipuram Cross Cut Road, Coimbatore, Tamil Nadu';
      } else if (lat > 11.02) {
        return 'Saravanampatti & IT Corridor, Coimbatore, Tamil Nadu';
      } else {
        return 'Avinashi Road & Peelamedu, Coimbatore, Tamil Nadu';
      }
    }
    // Tamil Nadu / Chennai Sector
    else if (lat >= 12.80 && lat <= 13.25 && lng >= 80.10 && lng <= 80.35) {
      return 'Anna Salai & T. Nagar, Chennai, Tamil Nadu';
    }
    // Telangana / Hyderabad Sector
    else if (lat >= 17.25 && lat <= 17.55 && lng >= 78.30 && lng <= 78.60) {
      return 'Banjara Hills Road #12, Hyderabad, Telangana';
    }
    // Maharashtra / Mumbai Sector
    else if (lat >= 18.85 && lat <= 19.30 && lng >= 72.75 && lng <= 73.05) {
      return 'Bandra Kurla Complex (BKC), Mumbai, Maharashtra';
    }
    // National Capital Region / Delhi
    else if (lat >= 28.40 && lat <= 28.90 && lng >= 76.90 && lng <= 77.40) {
      return 'Connaught Place & Outer Ring Road, New Delhi';
    }
    // General Regional India Dispatch Address
    else {
      return 'District Emergency Medical Corridor, India';
    }
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
