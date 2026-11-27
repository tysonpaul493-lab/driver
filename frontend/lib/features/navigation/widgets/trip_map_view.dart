import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/distance_utils.dart';

/// Real-time interactive high-accuracy map with live ambulance telemetry,
/// patient pickup, and hospital routing using OpenStreetMap / CartoDB tiles.
/// Does not require Google Maps API keys or billing.
class TripMapView extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final double heading;
  final double targetLat;
  final double targetLng;
  final String targetTitle;
  final bool isHeadingToHospital;
  final double accuracy;
  final VoidCallback? onRecenter;
  final ValueChanged<double>? onRouteDistanceUpdated;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? hospitalName;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;

  const TripMapView({
    super.key,
    required this.currentLat,
    required this.currentLng,
    this.heading = 0.0,
    required this.targetLat,
    required this.targetLng,
    required this.targetTitle,
    this.isHeadingToHospital = false,
    this.accuracy = 8.0,
    this.onRecenter,
    this.onRouteDistanceUpdated,
    this.hospitalLat,
    this.hospitalLng,
    this.hospitalName,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  double _currentZoom = 15.5;
  double _mapRotation = 0.0;
  bool _autoFollow = true;
  List<ll.LatLng> _routePoints = [];

  bool get _hasValidDriverCoord => _isValidCoord(widget.currentLat, widget.currentLng);

  @override
  void initState() {
    super.initState();
    _fetchRoadRoute();
  }

  @override
  void didUpdateWidget(covariant TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasValidDriver = _isValidCoord(oldWidget.currentLat, oldWidget.currentLng);
    final nowValidDriver = _hasValidDriverCoord;

    if (nowValidDriver &&
        _isMapReady &&
        (_autoFollow || !wasValidDriver) &&
        (oldWidget.currentLat != widget.currentLat ||
            oldWidget.currentLng != widget.currentLng)) {
      // Smoothly update map center when driver moves or gets initial GPS fix
      try {
        _mapController.move(
          ll.LatLng(widget.currentLat, widget.currentLng),
          _currentZoom,
        );
      } catch (_) {}
    }

    if ((!wasValidDriver && nowValidDriver) ||
        oldWidget.targetLat != widget.targetLat ||
        oldWidget.targetLng != widget.targetLng ||
        (_routePoints.isEmpty && nowValidDriver && _isValidCoord(widget.targetLat, widget.targetLng)) ||
        (oldWidget.currentLat - widget.currentLat).abs() > 0.002 ||
        (oldWidget.currentLng - widget.currentLng).abs() > 0.002) {
      _fetchRoadRoute();
    }
  }

  static bool _isValidCoord(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      !(lat == 0.0 && lng == 0.0) &&
      lat.abs() <= 90.0 &&
      lng.abs() <= 180.0;

  Future<void> _fetchRoadRoute() async {
    final startLat = widget.currentLat;
    final startLng = widget.currentLng;
    final endLat = widget.targetLat;
    final endLng = widget.targetLng;

    if (!_isValidCoord(startLat, startLng) || !_isValidCoord(endLat, endLng)) {
      return;
    }

    if (DistanceUtils.calculateDistanceInMeters(startLat, startLng, endLat, endLng) < 15.0) {
      if (mounted) {
        setState(() => _routePoints = [ll.LatLng(startLat, startLng), ll.LatLng(endLat, endLng)]);
        widget.onRouteDistanceUpdated?.call(0.0);
      }
      return;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          if (!kIsWeb) 'User-Agent': 'A2IDriver/1.0',
          'Accept': 'application/json',
        },
      ),
    );

    const mirrors = [
      'https://router.project-osrm.org/route/v1/driving',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving',
    ];

    try {
      for (final mirror in mirrors) {
        try {
          final url =
              '$mirror/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';
          final response = await dio.get(url);
          if (response.statusCode == 200 && response.data is Map) {
            final routes = response.data['routes'] as List?;
            if (routes != null && routes.isNotEmpty) {
              final geometry = routes[0]['geometry'];
              final coords = geometry?['coordinates'] as List?;
              final apiDistMeters = (routes[0]['distance'] as num?)?.toDouble();
              if (coords != null && coords.isNotEmpty) {
                final points = coords
                    .whereType<List>()
                    .where((c) => c.length >= 2)
                    .map(
                      (c) => ll.LatLng(
                        (c[1] as num).toDouble(),
                        (c[0] as num).toDouble(),
                      ),
                    )
                    .toList();
                if (mounted && points.length >= 2) {
                  setState(() => _routePoints = points);
                  final roadMeters = (apiDistMeters != null && apiDistMeters > 0)
                      ? apiDistMeters
                      : DistanceUtils.calculatePolylineMeters(
                          points.map((p) => (lat: p.latitude, lng: p.longitude)).toList(),
                        );
                  widget.onRouteDistanceUpdated?.call(roadMeters);
                  return;
                }
              }
            }
          }
        } catch (_) {}
      }
    } finally {
      dio.close();
    }

    if (mounted) {
      setState(() {
        _routePoints = [ll.LatLng(startLat, startLng), ll.LatLng(endLat, endLng)];
      });
      widget.onRouteDistanceUpdated?.call(
        DistanceUtils.calculateDrivingDistanceMeters(
          startLat,
          startLng,
          endLat,
          endLng,
        ),
      );
    }
  }

  void _recenterOnDriver() {
    _autoFollow = true;
    _currentZoom = 16.5;
    final target = _hasValidDriverCoord
        ? ll.LatLng(widget.currentLat, widget.currentLng)
        : (_isValidCoord(widget.targetLat, widget.targetLng)
              ? ll.LatLng(widget.targetLat, widget.targetLng)
              : null);
    if (target == null) return;
    try {
      _mapController.move(target, _currentZoom);
    } catch (_) {}
    widget.onRecenter?.call();
  }

  void _fitRouteBounds() {
    _autoFollow = false;
    try {
      final rawPoints = <ll.LatLng>[
        if (_hasValidDriverCoord) ll.LatLng(widget.currentLat, widget.currentLng),
        if (_isValidCoord(widget.targetLat, widget.targetLng))
          ll.LatLng(widget.targetLat, widget.targetLng),
        if (widget.hospitalLat != null && widget.hospitalLng != null)
          ll.LatLng(widget.hospitalLat!, widget.hospitalLng!),
        if (widget.pickupLat != null && widget.pickupLng != null)
          ll.LatLng(widget.pickupLat!, widget.pickupLng!),
      ];
      final points = rawPoints
          .where((p) => _isValidCoord(p.latitude, p.longitude))
          .toList();
      if (points.isEmpty) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15.5);
        return;
      }

      double south = points.first.latitude;
      double north = points.first.latitude;
      double west = points.first.longitude;
      double east = points.first.longitude;

      for (final p in points) {
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }

      final bounds = LatLngBounds(
        ll.LatLng(south, west),
        ll.LatLng(north, east),
      );

      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final driverPoint = ll.LatLng(widget.currentLat, widget.currentLng);
    final targetPoint = ll.LatLng(widget.targetLat, widget.targetLng);

    final pickupPoint = (widget.pickupLat != null &&
            widget.pickupLng != null &&
            _isValidCoord(widget.pickupLat!, widget.pickupLng!))
        ? ll.LatLng(widget.pickupLat!, widget.pickupLng!)
        : (!widget.isHeadingToHospital &&
                _isValidCoord(widget.targetLat, widget.targetLng)
            ? targetPoint
            : null);

    final hospitalPoint = (widget.hospitalLat != null &&
            widget.hospitalLng != null &&
            _isValidCoord(widget.hospitalLat!, widget.hospitalLng!))
        ? ll.LatLng(widget.hospitalLat!, widget.hospitalLng!)
        : (widget.isHeadingToHospital &&
                _isValidCoord(widget.targetLat, widget.targetLng)
            ? targetPoint
            : null);

    final markers = <Marker>[
      // 1. Driver Ambulance Live Marker (only shown once valid GPS coordinate is available)
      if (_hasValidDriverCoord)
        Marker(
          point: driverPoint,
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric halo ring
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x334285F4),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              // Core navigation puck
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF1A73E8), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: (widget.heading * math.pi / 180),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF1A73E8),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];

    // 2. Patient Pickup Location Marker (Red Pin with Badge)
    if (pickupPoint != null) {
      markers.add(
        Marker(
          point: pickupPoint,
          width: 170,
          height: 64,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.emergencyRed, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_pin_circle_rounded,
                      size: 12,
                      color: AppColors.emergencyRed,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Patient Pickup',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emergencyRed,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Destination Hospital Marker (Prominent Green Cross Badge with Hospital Name)
    if (hospitalPoint != null) {
      markers.add(
        Marker(
          point: hospitalPoint,
          width: 180,
          height: 72,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.statusGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_hospital_rounded,
                      size: 13,
                      color: AppColors.statusGreen,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        widget.hospitalName ?? 'Hospital Destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.statusGreen,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusGreen.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: Container(color: const Color(0xFF1E293B))),

        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _hasValidDriverCoord
                ? driverPoint
                : (_isValidCoord(targetPoint.latitude, targetPoint.longitude)
                      ? targetPoint
                      : const ll.LatLng(0.0, 0.0)),
            initialZoom: _currentZoom,
            initialRotation: _mapRotation,
            onMapReady: () {
              if (!mounted) return;
              setState(() => _isMapReady = true);
              if (_hasValidDriverCoord) {
                try {
                  _mapController.move(driverPoint, _currentZoom);
                } catch (_) {}
              } else if (_isValidCoord(targetPoint.latitude, targetPoint.longitude)) {
                try {
                  _mapController.move(targetPoint, _currentZoom);
                } catch (_) {}
              }
            },
            minZoom: 4.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: false,
              rotationThreshold: 8.0,
              pinchZoomThreshold: 0.15,
              pinchMoveThreshold: 15.0,
            ),
            onPositionChanged: (camera, hasGesture) {
              _currentZoom = camera.zoom;
              if (hasGesture && _autoFollow) {
                _autoFollow = false;
              }
            },
          ),
          children: [
            // Official Google Maps Roadmap tile layer (High-performance, daylight vector roads & POIs)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.a2i.driver',
              maxZoom: 19,
              fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            ),

            // High-Accuracy GPS Precision Circle around Ambulance
            if (_hasValidDriverCoord)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: driverPoint,
                    radius: widget.accuracy.clamp(12.0, 45.0),
                    useRadiusInMeter: false,
                    color: const Color(0x224285F4),
                    borderColor: const Color(0xFF4285F4),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // Emergency Road Pathway Polyline (Google Maps Navigation Style)
            if (_routePoints.isNotEmpty ||
                (_hasValidDriverCoord &&
                    _isValidCoord(targetPoint.latitude, targetPoint.longitude)))
              PolylineLayer(
                polylines: [
                  // Glowing route underlay casing
                  Polyline(
                    points: _routePoints.isNotEmpty
                        ? _routePoints
                        : [driverPoint, targetPoint],
                    strokeWidth: 9.0,
                    color:
                        (widget.isHeadingToHospital
                                ? AppColors.statusGreen
                                : const Color(0xFF4285F4))
                            .withValues(alpha: 0.35),
                  ),
                  // Route core line
                  Polyline(
                    points: _routePoints.isNotEmpty
                        ? _routePoints
                        : [driverPoint, targetPoint],
                    strokeWidth: 5.5,
                    color: widget.isHeadingToHospital
                        ? AppColors.statusGreen
                        : const Color(0xFF1A73E8),
                  ),
                ],
              ),

            // Markers Layer
            MarkerLayer(markers: markers),
          ],
        ),

        // Live Real-Time GPS Accuracy Badge (Top-Left)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.statusGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'GPS Live (±${widget.accuracy.toStringAsFixed(0)}m)',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recenter & Zoom & Compass Controls (Daylight Theme)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'compass_reset_north_nav',
                tooltip: 'Reset North',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ambulanceTeal,
                elevation: 3,
                onPressed: () {
                  try {
                    _mapController.rotate(0.0);
                    setState(() => _mapRotation = 0.0);
                  } catch (_) {}
                },
                child: Transform.rotate(
                  angle: -(_mapRotation * math.pi / 180.0),
                  child: const Icon(Icons.explore_rounded),
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'recenter_driver_live_gps',
                tooltip: 'Live Driver Location',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ambulanceTeal,
                elevation: 3,
                onPressed: _recenterOnDriver,
                child: const Icon(Icons.my_location_rounded),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'fit_route_bounds',
                tooltip: 'Fit Full Route',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.statusGreen,
                elevation: 3,
                onPressed: _fitRouteBounds,
                child: const Icon(Icons.route_rounded),
              ),
            ],
          ),
        ),
        // Clean In-App Map Attribution Badge (Bottom-Left)
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: 12,
                  color: AppColors.ambulanceTeal,
                ),
                SizedBox(width: 4),
                Text(
                  'A2I Live Map',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
