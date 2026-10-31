/// API Endpoints and configuration for connection to Laravel Backend & Indian Standards
class ApiConstants {
  // Configurable base URL (can be customized in-app via Settings)
  // For local development on Android emulator use http://10.0.2.2:8000/api/v1
  // For physical device over Wi-Fi use your PC's LAN IP e.g. http://192.168.1.5:8000/api/v1
  static const String defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  // Indian Emergency Dispatch & Ambulance Control Numbers
  static const String nationalAmbulanceEmergencyNumber = '108';
  static const String nationalDisasterHelpline = '112';
  static const String indiaDefaultCountryCode = '+91';

  // Standard Indian Initial Coordinates (Bengaluru / New Delhi)
  static const double defaultIndiaLat = 12.9716;
  static const double defaultIndiaLng = 77.5946;

  // Auth endpoints
  static const String sendOtp = '/driver/auth/send-otp';
  static const String verifyOtp = '/driver/auth/verify-otp';
  static const String register = '/driver/auth/register';
  static const String uploadDocuments = '/driver/documents/upload';
  static const String profile = '/driver/profile';
  static const String logout = '/driver/auth/logout';
  static const String updateFcmToken = '/driver/fcm-token';

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

  // Laravel Reverb / Pusher WebSocket Config
  static const String reverbHost = '10.0.2.2';
  static const int reverbPort = 8080;
  static const String reverbScheme = 'http';
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
