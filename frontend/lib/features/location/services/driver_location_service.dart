import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Live telemetry packet transmitted to Laravel backend
class LocationTelemetry {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final DateTime timestamp;
  final bool isGpsStale;

  LocationTelemetry({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.timestamp,
    this.isGpsStale = false,
  });
}

/// Service managing device GPS updates, battery optimization, and telemetry broadcasting
class DriverLocationService {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _staleGpsTimer;
  DateTime? _lastPingTime;
  Position? _currentPosition;
  String? _activeBookingReference;

  final _telemetryController = StreamController<LocationTelemetry>.broadcast();
  Stream<LocationTelemetry> get onTelemetryUpdated => _telemetryController.stream;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _positionSubscription != null;

  DriverLocationService(this._dioClient, this._storageService);

  /// Verify and request high-accuracy location permissions
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location service disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Get current instantaneous fix
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
        _currentPosition = position;
        return position;
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _currentPosition = last;
          return last;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LocationService] Error fetching current position: $e');
      return null;
    }
  }

  /// Start live location tracking during an active trip or when online
  Future<void> startTracking({String? bookingReference}) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    _activeBookingReference = bookingReference;
    await stopTracking(); // Clean any previous subscription

    // Balanced location settings: High accuracy, 10m movement filter to preserve battery
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only fire when vehicle moves 10 meters
    );

    _resetStaleTimer();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        _resetStaleTimer();

        final telemetry = LocationTelemetry(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          heading: position.heading,
          speed: position.speed,
          timestamp: position.timestamp,
          isGpsStale: false,
        );

        _telemetryController.add(telemetry);
        _sendTelemetryToBackend(position);
      },
      onError: (e) {
        debugPrint('[LocationService] Position stream error: $e');
      },
    );
  }

  /// Transmit GPS packet to Laravel backend
  Future<void> _sendTelemetryToBackend(Position position) async {
    final now = DateTime.now();
    // Throttle network transmissions to once every 3.5 seconds minimum to save mobile data
    if (_lastPingTime != null && now.difference(_lastPingTime!).inMilliseconds < 3500) {
      return;
    }

    _lastPingTime = now;
    final driverId = await _storageService.getDriverId();

    try {
      await _dioClient.post(
        ApiConstants.updateLocation,
        data: {
          'driver_id': driverId,
          'booking_reference': _activeBookingReference,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': position.timestamp.toIso8601String(),
        },
      );
    } catch (e) {
      // In poor network conditions, silently tolerate dropped pings; the next move will transmit
      debugPrint('[LocationService] Telemetry ping skipped/dropped: $e');
    }
  }

  void _resetStaleTimer() {
    _staleGpsTimer?.cancel();
    _staleGpsTimer = Timer(const Duration(seconds: 15), () {
      if (_currentPosition != null) {
        _telemetryController.add(
          LocationTelemetry(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            accuracy: _currentPosition!.accuracy,
            heading: _currentPosition!.heading,
            speed: 0.0,
            timestamp: _currentPosition!.timestamp,
            isGpsStale: true,
          ),
        );
      }
    });
  }

  /// Stop tracking immediately when trip completes or driver goes offline
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _staleGpsTimer?.cancel();
    _staleGpsTimer = null;
    _activeBookingReference = null;
  }

  void dispose() {
    stopTracking();
    _telemetryController.close();
  }
}
