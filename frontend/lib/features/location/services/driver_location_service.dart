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
  Timer? _heartbeatTimer;
  DateTime? _lastPingTime;
  DateTime? _lastGpsSampleTime;
  bool _isTelemetryInFlight = false;
  bool _isHeartbeatSampling = false;
  int _trackingEpoch = 0;
  Position? _currentPosition;
  String? _activeBookingReference;

  final _telemetryController = StreamController<LocationTelemetry>.broadcast();
  Stream<LocationTelemetry> get onTelemetryUpdated =>
      _telemetryController.stream;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _positionSubscription != null || _heartbeatTimer != null;

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

  Future<Position?> _acquireBestPosition({
    Duration highTimeout = const Duration(seconds: 5),
    Duration fallbackTimeout = const Duration(seconds: 3),
  }) async {
    final attempts = <(LocationAccuracy, Duration)>[
      (LocationAccuracy.high, highTimeout),
      (LocationAccuracy.medium, fallbackTimeout),
      (LocationAccuracy.low, fallbackTimeout),
    ];

    for (final (accuracy, timeout) in attempts) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: timeout,
        );
        return pos;
      } catch (_) {
        // Fallback to coarser accuracy when indoor/cold GPS times out
      }
    }

    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Get current instantaneous fix
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      final position = await _acquireBestPosition();
      if (position != null) {
        _currentPosition = position;
      }
      return position;
    } catch (e) {
      debugPrint('[LocationService] Error fetching current position: $e');
      return null;
    }
  }

  /// Start live location tracking during an active trip or when online
  Future<void> startTracking({String? bookingReference}) async {
    // Do not wipe active-trip booking telemetry if a generic online tracking call fires concurrently
    if (isTracking &&
        bookingReference == null &&
        _activeBookingReference != null) {
      return;
    }

    // Fast-path when GPS stream & heartbeat are already alive: attach active booking without teardown
    if (isTracking && _heartbeatTimer != null) {
      _activeBookingReference = bookingReference ?? _activeBookingReference;
      _resetStaleTimer();
      if (_currentPosition != null) {
        unawaited(_emitPosition(_currentPosition!, forceNetworkSync: true));
      } else {
        unawaited(_sampleInitialFix(_trackingEpoch));
      }
      return;
    }

    final int epoch = ++_trackingEpoch;
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission || epoch != _trackingEpoch) return;

    await _teardownTrackingStreams(clearBookingRef: false);
    if (epoch != _trackingEpoch) return;
    _activeBookingReference = bookingReference;

    // High accuracy, 3m movement filter with Android Foreground Service notification for locked-screen/background GPS
    final LocationSettings locationSettings =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ? AndroidSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 3,
                intervalDuration: const Duration(seconds: 4),
                foregroundNotificationConfig: const ForegroundNotificationConfig(
                  notificationTitle: 'LifeRoute Driver Online',
                  notificationText:
                      'Live ambulance GPS tracking & emergency dispatch active.',
                  notificationChannelName: 'Ambulance Live GPS Tracking',
                  enableWifiLock: true,
                  enableWakeLock: true,
                  setOngoing: true,
                ),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 3,
              );

    _resetStaleTimer();

    try {
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
              _emitPosition(position);
            },
            onError: (e) {
              debugPrint('[LocationService] Position stream error: $e');
            },
          );
    } catch (e) {
      debugPrint('[LocationService] Position stream setup failed: $e');
    }

    // Immediately broadcast cached fix if present, and start non-overlapping heartbeat right away
    if (_currentPosition != null) {
      unawaited(_emitPosition(_currentPosition!, forceNetworkSync: true));
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (epoch != _trackingEpoch) return;
      if (!isTracking && _heartbeatTimer == null) return;
      if (_isHeartbeatSampling) return;
      _isHeartbeatSampling = true;
      try {
        final gpsAgeMs = _lastGpsSampleTime == null
            ? 999999
            : DateTime.now().difference(_lastGpsSampleTime!).inMilliseconds;
        Position? pos = _currentPosition;
        // Sample fresh GPS only if cached fix is missing or older than 4 seconds
        if (pos == null || gpsAgeMs >= 4000) {
          pos = await _acquireBestPosition(
                highTimeout: const Duration(seconds: 3),
                fallbackTimeout: const Duration(seconds: 2),
              ) ??
              _currentPosition;
        }
        if (pos != null && epoch == _trackingEpoch) {
          await _emitPosition(pos);
        }
      } finally {
        _isHeartbeatSampling = false;
      }
    });

    // Fetch fresh initial GPS asynchronously without blocking caller or delaying heartbeat setup
    unawaited(_sampleInitialFix(epoch));
  }

  Future<void> _sampleInitialFix(int epoch) async {
    final initialPos = await getCurrentPosition();
    if (initialPos != null && epoch == _trackingEpoch && _heartbeatTimer != null) {
      await _emitPosition(initialPos, forceNetworkSync: true);
    }
  }

  Future<void> _emitPosition(
    Position position, {
    bool forceNetworkSync = false,
  }) async {
    _currentPosition = position;
    _lastGpsSampleTime = DateTime.now();
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
    await _sendTelemetryToBackend(position, force: forceNetworkSync);
  }

  /// Transmit GPS packet to dispatch backend
  Future<void> _sendTelemetryToBackend(
    Position position, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    // Throttle network transmissions to once every 4 seconds minimum to save mobile data
    if (!force && _lastPingTime != null && now.difference(_lastPingTime!).inMilliseconds < 4000) {
      return;
    }
    if (_isTelemetryInFlight) {
      return;
    }

    _lastPingTime = now;
    _isTelemetryInFlight = true;
    try {
      final driverId = await _storageService.getDriverId();
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
    } finally {
      _isTelemetryInFlight = false;
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

  Future<void> _teardownTrackingStreams({bool clearBookingRef = true}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _staleGpsTimer?.cancel();
    _staleGpsTimer = null;
    if (clearBookingRef) {
      _activeBookingReference = null;
    }
  }

  /// Stop tracking immediately when trip completes or driver goes offline
  Future<void> stopTracking() async {
    _trackingEpoch++;
    await _teardownTrackingStreams(clearBookingRef: true);
  }

  void dispose() {
    stopTracking();
    _telemetryController.close();
  }
}
