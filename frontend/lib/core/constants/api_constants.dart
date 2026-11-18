import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const String _kDefaultLiveWebBackend = 'https://bottle-equilibrium-vcr-introductory.trycloudflare.com/api/v1';

String get _detectedHost {
  if (ApiConstants.configuredApiUrl.isNotEmpty) {
    return ApiConstants.configuredApiUrl;
  }
  // Primary default for standalone Android APK and Web: Live Cloudflare Dispatch Gateway
  return _kDefaultLiveWebBackend;
}

/// API Endpoints and Dispatch Network Configuration
class ApiConstants {
  /// Default PC LAN IP used automatically on mobile devices when USB adb reverse is unavailable.
  /// Can be overridden at build time via `--dart-define=DEFAULT_LAN_HOST=...` or in-app settings.
  static const String fallbackLanHost = String.fromEnvironment(
    'DEFAULT_LAN_HOST',
    defaultValue: '192.168.0.112',
  );
  static const String configuredApiUrl = String.fromEnvironment(
    'DEFAULT_API_URL',
    defaultValue: '',
  );

  static String? _customServerHost;
  static String? _customFullBaseUrl;
  static String? _runtimeFallbackHost;

  /// Effective server IP/hostname for both REST API and live WebSocket dispatch
  static String get effectiveHost {
    if (kIsWeb) {
      if (_customServerHost != null &&
          _customServerHost!.isNotEmpty &&
          !_customServerHost!.contains('localhost') &&
          !_customServerHost!.contains('127.0.0.1')) {
        return _customServerHost!;
      }
      return _kDefaultLiveWebBackend;
    }
    return _customServerHost ?? _runtimeFallbackHost ?? _detectedHost;
  }

  static bool get hasCustomServerHost =>
      _customServerHost != null &&
      (!kIsWeb || (!_customServerHost!.contains('localhost') && !_customServerHost!.contains('127.0.0.1')));

  /// User-friendly label of the current server endpoint for notifications and error messages
  static String get displayServerEndpoint {
    if (kIsWeb) {
      return 'Cloudflare Dispatch Gateway';
    }
    if (effectiveHost.startsWith('http://') || effectiveHost.startsWith('https://')) {
      return effectiveHost.replaceAll(RegExp(r'^https?://'), '');
    }
    return '$effectiveHost:8000';
  }

  /// Ordered unique list of candidate backend hosts for automatic connection resolution.
  static List<String> get candidateHosts {
    if (kIsWeb) {
      return [
        if (hasCustomServerHost) _customServerHost! else _kDefaultLiveWebBackend,
      ];
    }

    final hosts = <String>[];
    void addHost(String? value) {
      final cleaned = value?.trim() ?? '';
      if (cleaned.isNotEmpty && !hosts.contains(cleaned)) {
        hosts.add(cleaned);
      }
    }

    if (_customServerHost != null && _customServerHost!.isNotEmpty) {
      addHost(_customServerHost);
      return hosts;
    }

    addHost(_runtimeFallbackHost);
    addHost(_kDefaultLiveWebBackend);
    addHost(fallbackLanHost);
    try {
      if (Platform.isAndroid) {
        addHost('10.0.2.2');
        addHost('127.0.0.1');
      }
    } catch (_) {}
    addHost('localhost');
    return hosts;
  }

  /// Configure detected runtime fallback host without overwriting explicit user setting.
  static void setRuntimeFallbackHost(String? host) {
    final trimmed = host?.trim() ?? '';
    _runtimeFallbackHost = trimmed.isEmpty ? null : trimmed;
  }

  /// Configure custom server host/IP (or null/empty to revert to automatic detection)
  static void setServerHost(String? rawHost) {
    final trimmed = rawHost?.trim() ?? '';
    if (trimmed.isEmpty) {
      _customServerHost = null;
      _customFullBaseUrl = null;
      _runtimeFallbackHost = null;
      return;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      var url = trimmed;
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      if (!url.endsWith('/api/v1') && !url.endsWith('/api')) {
        url = '$url/api/v1';
      }
      _customFullBaseUrl = url;

      var cleaned = trimmed.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
      cleaned = cleaned.split('/').first.trim();
      if (cleaned.contains(':')) {
        cleaned = cleaned.split(':').first.trim();
      }
      _customServerHost = cleaned.isEmpty ? null : cleaned;
      _runtimeFallbackHost = null;
      return;
    }

    var cleaned = trimmed.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    cleaned = cleaned.split('/').first.trim();
    if (cleaned.contains(':')) {
      cleaned = cleaned.split(':').first.trim();
    }
    _customServerHost = cleaned.isEmpty ? null : cleaned;
    _customFullBaseUrl = null;
    _runtimeFallbackHost = null;
  }

  /// Build base API URL for an explicit host
  static String baseUrlForHost(String host) {
    if (kIsWeb) {
      if (_customFullBaseUrl != null &&
          _customFullBaseUrl!.isNotEmpty &&
          !_customFullBaseUrl!.contains('localhost') &&
          !_customFullBaseUrl!.contains('127.0.0.1')) {
        return _customFullBaseUrl!;
      }
      if (host.startsWith('http://') || host.startsWith('https://')) {
        if (!host.contains('localhost') && !host.contains('127.0.0.1')) {
          var url = host;
          if (url.endsWith('/')) url = url.substring(0, url.length - 1);
          if (!url.endsWith('/api/v1') && !url.endsWith('/api')) url = '$url/api/v1';
          return url;
        }
      }
      return _kDefaultLiveWebBackend;
    }
    if (_customFullBaseUrl != null && _customFullBaseUrl!.isNotEmpty) {
      return _customFullBaseUrl!;
    }
    if (configuredApiUrl.isNotEmpty) {
      return configuredApiUrl;
    }
    if (host.startsWith('http://') || host.startsWith('https://')) {
      var url = host;
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      if (!url.endsWith('/api/v1') && !url.endsWith('/api')) url = '$url/api/v1';
      return url;
    }
    return 'http://$host:8000/api/v1';
  }

  // Configurable base URL (can be customized in-app via Server Connection settings)
  // For USB debugging use 127.0.0.1 with adb reverse
  // For multi-device Wi-Fi LAN use PC LAN IP e.g. 192.168.0.112
  static String get defaultBaseUrl {
    if (_customFullBaseUrl != null &&
        _customFullBaseUrl!.isNotEmpty &&
        !_customFullBaseUrl!.contains('localhost') &&
        !_customFullBaseUrl!.contains('127.0.0.1')) {
      return _customFullBaseUrl!;
    }
    if (configuredApiUrl.isNotEmpty &&
        !configuredApiUrl.contains('localhost') &&
        !configuredApiUrl.contains('127.0.0.1')) {
      return configuredApiUrl;
    }
    if (_runtimeFallbackHost != null && _runtimeFallbackHost!.isNotEmpty) {
      return baseUrlForHost(_runtimeFallbackHost!);
    }
    return _kDefaultLiveWebBackend;
  }

  // Indian Emergency Dispatch & Ambulance Control Numbers
  static const String nationalAmbulanceEmergencyNumber = '108';
  static const String nationalDisasterHelpline = '112';
  static const String indiaDefaultCountryCode = '+91';

  // Standard Indian Initial Coordinates (Bengaluru / New Delhi)
  static const double defaultIndiaLat = 12.9716;
  static const double defaultIndiaLng = 77.5946;

  // Auth endpoints
  static const String checkPhone = '/driver/auth/check-phone';
  static const String sendOtp = '/driver/auth/send-otp';
  static const String verifyOtp = '/driver/auth/verify-otp';
  static const String loginWithPassword = '/driver/auth/login';
  static const String resetPassword = '/driver/auth/reset-password';
  static const String register = '/driver/auth/register';
  static const String uploadDocuments = '/driver/documents/upload';
  static const String profile = '/driver/profile';
  static const String logout = '/driver/auth/logout';

  // Dashboard & Status endpoints
  static const String dashboardSummary = '/driver/dashboard/summary';
  static const String toggleOnlineStatus = '/driver/status/toggle';
  static const String verificationStatus = '/driver/verification-status';

  // Booking Requests & Dispatch endpoints
  static const String pendingRequests = '/driver/requests/pending';
  static const String acceptBooking = '/driver/requests/{id}/accept';
  static const String declineBooking = '/driver/requests/{id}/decline';

  // Active Trip & Workflow endpoints
  static const String activeTrip = '/driver/trips/active';
  static const String tripDetails = '/driver/trips/{id}';
  static const String updateTripStatus = '/driver/trips/{id}/status';

  // Live GPS Telemetry endpoint
  static const String updateLocation = '/driver/location/telemetry';

  // History & Notifications
  static const String tripHistory = '/driver/trips/history';
  static const String notifications = '/driver/notifications';
  static const String markNotificationRead = '/driver/notifications/{id}/read';
  static const String supportHelpline = '/driver/support/info';

  // Live Dispatch WebSocket Config
  static String get reverbHost => effectiveHost.contains('trycloudflare.com')
      ? 'campus-virgin-plants-termination.trycloudflare.com'
      : effectiveHost;
  static int get reverbPort => reverbHost.contains('trycloudflare.com') ? 443 : 8080;
  static String get reverbScheme => reverbHost.contains('trycloudflare.com') ? 'https' : 'http';
  static const String reverbAppKey = 'liferoute_reverb_key';
  static const String reverbAuthEndpoint = '/broadcasting/auth';

  // Channels
  static String driverPrivateChannel(int driverId) => 'private-driver.$driverId';
  static String bookingPrivateChannel(int bookingId) => 'private-booking.$bookingId';
  static const String emergencyBroadcastChannel = 'emergency-broadcasts';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
