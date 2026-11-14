import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liferoute_driver/core/constants/api_constants.dart';
import 'package:liferoute_driver/core/network/api_exception.dart';
import 'package:liferoute_driver/core/network/auth_interceptor.dart';
import 'package:liferoute_driver/core/network/dio_client.dart';
import 'package:liferoute_driver/core/utils/distance_utils.dart';
import 'package:liferoute_driver/core/utils/phone_utils.dart';
import 'package:liferoute_driver/core/storage/secure_storage_service.dart';
import 'package:liferoute_driver/features/active_trip/models/trip_status.dart';
import 'package:liferoute_driver/features/active_trip/providers/active_trip_provider.dart';
import 'package:liferoute_driver/features/auth/models/auth_response.dart';
import 'package:liferoute_driver/features/auth/providers/auth_provider.dart';
import 'package:liferoute_driver/features/auth/repositories/auth_repository.dart';
import 'package:liferoute_driver/features/auth/screens/driver_registration_screen.dart';
import 'package:liferoute_driver/features/auth/screens/phone_login_screen.dart';
import 'package:liferoute_driver/shared/widgets/otp_bars_widget.dart';
import 'package:liferoute_driver/features/location/providers/location_provider.dart';
import 'package:liferoute_driver/features/location/services/driver_location_service.dart';
import 'package:liferoute_driver/features/requests/models/booking_request_model.dart';
import 'package:liferoute_driver/features/dashboard/models/dashboard_summary_model.dart';
import 'package:liferoute_driver/core/websocket/reverb_provider.dart';
import 'package:liferoute_driver/core/websocket/reverb_service.dart';
import 'package:liferoute_driver/features/active_trip/models/trip_model.dart';
import 'package:liferoute_driver/features/auth/models/driver_model.dart';
import 'package:liferoute_driver/features/auth/models/vehicle_model.dart';
import 'package:liferoute_driver/features/auth/screens/document_upload_screen.dart';
import 'package:liferoute_driver/features/notifications/screens/notifications_screen.dart';
import 'package:liferoute_driver/features/requests/providers/requests_provider.dart';
import 'package:liferoute_driver/features/requests/repositories/requests_repository.dart';

class _TestErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
}

class _FakeLocationService extends DriverLocationService {
  final _ctrl = StreamController<LocationTelemetry>.broadcast();
  bool trackingFlag = true;

  _FakeLocationService(SecureStorageService storage)
    : super(DioClient(storage), storage);

  @override
  Stream<LocationTelemetry> get onTelemetryUpdated => _ctrl.stream;

  @override
  bool get isTracking => trackingFlag;

  @override
  Future<Position?> getCurrentPosition() async => null;

  void emitTestTelemetry(LocationTelemetry telemetry) {
    _ctrl.add(telemetry);
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<void> saveRegisteredDriverByPhone(
    String phone,
    Map<String, dynamic> profile,
  ) async {}
}

class _FakeAuthRepository extends AuthRepository {
  bool gatewayReady = false;
  String? lastSentPhone;
  String expectedOtp = '492817';

  _FakeAuthRepository(SecureStorageService storage)
    : super(DioClient(storage), storage);

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    lastSentPhone = phone;
    if (!gatewayReady) {
      throw ApiException(
        message: 'SMS gateway is not configured on the dispatch server yet.',
        statusCode: 503,
      );
    }
    return {'status': 'success', 'sms_dispatched': true, 'otp_expires_in': 300};
  }

  @override
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    if (otp != expectedOtp) {
      throw ApiException(
        message: 'Invalid SMS verification code.',
        statusCode: 401,
      );
    }
    return AuthResponse(
      token: 'test_driver_token',
      driver: DriverModel(
        id: 1,
        name: 'Muruganandam',
        phone: phone,
        email: '',
        licenseNumber: 'TN-01-2020',
        licenseExpiryDate: '2030-12-31',
        emergencyContact: '',
        verificationStatus: VerificationStatus.approved,
        isOnline: true,
        documentsUploaded: const {},
      ),
    );
  }

  @override
  Future<AuthResponse> loginWithPassword(String phone, String password) async {
    if (password != 'secure123') {
      throw ApiException(message: 'Incorrect password', statusCode: 401);
    }
    return AuthResponse(
      token: 'test_password_token',
      driver: DriverModel.fromJson({
        'id': 1,
        'name': 'Muruganandam',
        'phone': phone,
        'is_online': true,
        'verification_status': 'approved',
      }),
    );
  }

  @override
  Future<AuthResponse> resetPassword(
    String phone,
    String newPassword,
    String confirmPassword,
  ) async {
    return AuthResponse(
      token: 'test_reset_token',
      driver: DriverModel.fromJson({
        'id': 1,
        'name': 'Muruganandam',
        'phone': phone,
        'is_online': true,
        'verification_status': 'approved',
      }),
    );
  }

  @override
  Future<AuthResponse> registerDriver({
    required String name,
    required String phone,
    String? password,
    required String email,
    required String emergencyContact,
    required String licenseNumber,
    required String licenseExpiryDate,
    required String ambulanceRegNumber,
    required String vehicleType,
    required String makeModel,
    required int year,
    required List<String> equipmentList,
    required String operatorAffiliation,
    required String permitNumber,
    required String permitExpiryDate,
    required String insurancePolicyNumber,
    required String insuranceExpiryDate,
  }) async {
    return AuthResponse(
      token: 'test_registered_token',
      driver: DriverModel(
        id: 99,
        name: name,
        phone: phone,
        email: email,
        licenseNumber: licenseNumber,
        licenseExpiryDate: licenseExpiryDate,
        emergencyContact: emergencyContact,
        verificationStatus: VerificationStatus.approved,
        isOnline: false,
        documentsUploaded: const {},
      ),
    );
  }
}

void main() {
  group('LifeRoute Driver - Requested Features Verification', () {
    test('1. Booking Request countdown is 120s (2 minutes) and includes patient phone', () {
      final request = BookingRequestModel(
        id: 101,
        bookingReference: 'BK-12345',
        pickupAddress: 'Indiranagar 100ft Road',
        pickupLandmark: 'Metro Pillar 42',
        pickupLatitude: 12.9784,
        pickupLongitude: 77.6408,
        destinationHospital: 'Manipal Hospital HAL',
        destinationAddress: 'HAL Old Airport Road',
        destinationLatitude: 12.9592,
        destinationLongitude: 77.6540,
        emergencyCategory: 'Critical',
        essentialInstructions: 'Oxygen cylinder needed',
        countdownSeconds: 120,
        createdAt: DateTime.now(),
        patientName: 'Arjun Mehta',
        patientPhone: '+91 98450 12345',
      );

      expect(request.countdownSeconds, 120);
      expect(request.patientName, 'Arjun Mehta');
      expect(request.patientPhone, '+91 98450 12345');
    });

    test(
      '2. Dashboard Summary model copyWith updates all operational metrics',
      () {
        final initial = DashboardSummaryModel(
          completedTripsToday: 2,
          distanceCoveredKm: 18.5,
          onlineHours: 3.2,
          emergencyCriticalTrips: 1,
          earningsToday: 1500.0,
        );

        final updated = initial.copyWith(
          completedTripsToday: initial.completedTripsToday + 1,
          distanceCoveredKm: initial.distanceCoveredKm + 6.2,
          onlineHours: initial.onlineHours + 0.5,
          emergencyCriticalTrips: initial.emergencyCriticalTrips + 1,
          earningsToday: initial.earningsToday + 850.0,
        );

        expect(updated.completedTripsToday, 3);
        expect(updated.distanceCoveredKm, closeTo(24.7, 0.01));
        expect(updated.onlineHours, closeTo(3.7, 0.01));
        expect(updated.emergencyCriticalTrips, 2);
        expect(updated.earningsToday, 2350.0);
      },
    );

    test('3. Driver Model copyWith preserves vehicle and registration updates across app', () {
      final driver = DriverModel(
        id: 1,
        name: 'Rajesh Kumar',
        phone: '+91 98765 43210',
        email: 'rajesh.driver@liferoute.in',
        licenseNumber: 'KA-01-2018-0098234',
        licenseExpiryDate: '2028-12-31',
        emergencyContact: '+91 98765 99999',
        verificationStatus: VerificationStatus.approved,
        isOnline: true,
        documentsUploaded: const {},
        assignedVehicle: VehicleModel(
          registrationNumber: 'KA-01-EA-1080',
          vehicleType: VehicleType.als,
          makeModel: 'Force Traveller ICU Ambulance',
          year: 2024,
          equipmentList: ['Ventilator', 'Defibrillator'],
          operatorAffiliation: 'Manipal Emergency Network',
          permitNumber: 'KA-AMB-2024-998',
          permitExpiryDate: '2026-12-31',
          insurancePolicyNumber: 'HDFC-ERGO-AMB-99812',
          insuranceExpiryDate: '2025-11-30',
        ),
      );

      expect(driver.name, 'Rajesh Kumar');
      expect(driver.assignedVehicle?.registrationNumber, 'KA-01-EA-1080');

      final updated = driver.copyWith(
        name: 'Rajesh K. Sharma',
        assignedVehicle: driver.assignedVehicle?.copyWith(
          registrationNumber: 'KA-01-EA-9999',
          makeModel: 'Mercedes Sprinter ALS',
        ),
      );

      expect(updated.name, 'Rajesh K. Sharma');
      expect(updated.assignedVehicle?.registrationNumber, 'KA-01-EA-9999');
      expect(updated.assignedVehicle?.makeModel, 'Mercedes Sprinter ALS');
    });

    test('4. TripStatus.fromApi maps backend status aliases and ApiConstants normalizes LAN host', () {
      expect(TripStatus.fromApi('driver_assigned'), TripStatus.accepted);
      expect(
        TripStatus.fromApi('driver_approaching'),
        TripStatus.enRouteToPickup,
      );
      expect(TripStatus.fromApi('driver_arrived'), TripStatus.arrivedAtPickup);
      expect(
        TripStatus.fromApi('patient_picked_up'),
        TripStatus.patientOnboard,
      );
      expect(
        TripStatus.fromApi('traveling_to_hospital'),
        TripStatus.inTransitToHospital,
      );
      expect(
        TripStatus.fromApi('arrived_at_hospital'),
        TripStatus.arrivedAtHospital,
      );
      expect(TripStatus.fromApi('trip_completed'), TripStatus.completed);

      ApiConstants.setServerHost('http://192.168.1.42:8000/api/v1');
      expect(ApiConstants.effectiveHost, '192.168.1.42');
      expect(ApiConstants.reverbHost, '192.168.1.42');
      expect(ApiConstants.defaultBaseUrl, 'http://192.168.1.42:8000/api/v1');
      ApiConstants.setServerHost(null);
      expect(ApiConstants.hasCustomServerHost, isFalse);
    });

    test('5. PhoneUtils formats local and international phone numbers to E.164 cleanly', () {
      expect(
        PhoneUtils.formatInternationalPhone('9876543210'),
        '+919876543210',
      );
      expect(
        PhoneUtils.formatInternationalPhone('+91 98765 43210'),
        '+919876543210',
      );
      expect(
        PhoneUtils.formatInternationalPhone('+1 415 555 2671'),
        '+14155552671',
      );
      expect(
        PhoneUtils.buildInternationalPhone('+91', '08428304510'),
        '+918428304510',
      );
      expect(
        PhoneUtils.buildInternationalPhone('+91', '+91 84283 04510'),
        '+918428304510',
      );
      expect(
        PhoneUtils.buildInternationalPhone('+91', '84283 04510'),
        '+918428304510',
      );
    });

    test('6. ActiveTripState tracks live patient chat messages, unread badge count, and resets on clearTrip', () {
      const initial = ActiveTripState();
      expect(initial.chatMessages, isEmpty);
      expect(initial.unreadChatCount, 0);

      final withChat = initial.copyWith(
        chatMessages: const [
          {
            'id': 1,
            'sender_type': 'patient',
            'sender_name': 'Patient',
            'message': 'Near main gate',
          },
        ],
        unreadChatCount: 1,
      );
      expect(withChat.chatMessages.length, 1);
      expect(withChat.chatMessages.first['message'], 'Near main gate');
      expect(withChat.unreadChatCount, 1);

      final cleared = withChat.copyWith(clearTrip: true);
      expect(cleared.trip, isNull);
      expect(cleared.chatMessages, isEmpty);
      expect(cleared.unreadChatCount, 0);
    });

    testWidgets(
      '7. PhoneLoginScreen uses mobile-number password login with forgot password link',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(
                _FakeSecureStorageService(),
              ),
            ],
            child: const MaterialApp(home: PhoneLoginScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Driver Sign In'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Forgot Password?'), findsOneWidget);
        expect(find.text('Request OTP'), findsNothing);
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );

    test('8. AuthNotifier sends real SMS OTP via gateway and enforces exact manual 6-digit verification', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _FakeSecureStorageService();
      final repo = _FakeAuthRepository(storage);
      final notifier = AuthNotifier(repo, storage);

      final unconfiguredOk = await notifier.sendOtp('8428304510');
      expect(unconfiguredOk, isFalse);
      expect(
        notifier.state.errorMessage,
        contains('SMS gateway is not configured'),
      );

      repo.gatewayReady = true;
      final sentOk = await notifier.sendOtp('8428304510');
      expect(sentOk, isTrue);
      expect(repo.lastSentPhone, '+918428304510');
      expect(notifier.state.otpSentToPhone, '+918428304510');

      final badLengthOk = await notifier.verifyOtp('123');
      expect(badLengthOk, isFalse);

      final wrongCodeOk = await notifier.verifyOtp('123456');
      expect(wrongCodeOk, isFalse);
      expect(
        notifier.state.errorMessage,
        contains('Invalid SMS verification code'),
      );

      final validCodeOk = await notifier.verifyOtp('492817');
      expect(validCodeOk, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.driver?.phone, '+918428304510');
    });

    test('9. AuthInterceptor ignores 401 on /auth/ endpoints while clearing session on protected routes', () {
      int unauthorizedCount = 0;
      final storage = _FakeSecureStorageService();
      final interceptor = AuthInterceptor(
        storage,
        onUnauthorized: () => unauthorizedCount++,
      );

      final authReq = RequestOptions(path: '/driver/auth/verify-otp');
      interceptor.onError(
        DioException(
          requestOptions: authReq,
          response: Response(requestOptions: authReq, statusCode: 401),
        ),
        _TestErrorHandler(),
      );
      expect(unauthorizedCount, 0);

      final profileReq = RequestOptions(path: '/driver/profile');
      interceptor.onError(
        DioException(
          requestOptions: profileReq,
          response: Response(requestOptions: profileReq, statusCode: 401),
        ),
        _TestErrorHandler(),
      );
      expect(unauthorizedCount, 1);
    });

    test('10. DriverLocationNotifier updates coordinates immediately without waiting on reverse geocode HTTP', () async {
      final service = _FakeLocationService(_FakeSecureStorageService());
      final notifier = DriverLocationNotifier(service);

      service.emitTestTelemetry(
        LocationTelemetry(
          latitude: 12.9784,
          longitude: 77.6408,
          accuracy: 8.5,
          heading: 112.0,
          speed: 11.4,
          timestamp: DateTime(2026, 11, 12, 11, 20),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.latitude, closeTo(12.9784, 0.0001));
      expect(notifier.state.longitude, closeTo(77.6408, 0.0001));
      expect(notifier.state.heading, closeTo(112.0, 0.01));
      expect(notifier.state.speed, closeTo(11.4, 0.01));
      expect(notifier.state.isTracking, isTrue);
      expect(notifier.state.currentAddress, isNotNull);

      notifier.dispose();
    });

    test('11. ApiConstants tracks runtime fallback LAN host and candidate list accurately', () {
      ApiConstants.setServerHost(null);
      ApiConstants.setRuntimeFallbackHost('192.168.0.112');
      expect(ApiConstants.hasCustomServerHost, isFalse);
      expect(ApiConstants.effectiveHost, '192.168.0.112');
      expect(ApiConstants.candidateHosts, contains('192.168.0.112'));

      ApiConstants.setServerHost(null);
      expect(ApiConstants.hasCustomServerHost, isFalse);
    });

    testWidgets(
      '12. PhoneLoginScreen Register button opens DriverRegistrationScreen prefilled with entered digits',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(
                _FakeSecureStorageService(),
              ),
            ],
            child: const MaterialApp(home: PhoneLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '9876543210');
        final registerBtn = find.text(
          'New Driver? Register Driver & Ambulance',
        );
        expect(registerBtn, findsOneWidget);

        await tester.ensureVisible(registerBtn);
        await tester.tap(registerBtn);
        await tester.pumpAndSettle();

        expect(find.byType(DriverRegistrationScreen), findsOneWidget);
        expect(find.text('Driver & Ambulance Registration'), findsOneWidget);
        expect(find.text('9876543210'), findsOneWidget);
      },
    );

    testWidgets(
      '13. DriverOtpBarsWidget shows soft keyboard on tap even when already focused and completes 6-digit OTP once',
      (WidgetTester tester) async {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        int textInputShowCalls = 0;
        String? completedOtp;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          (MethodCall call) async {
            if (call.method == 'TextInput.show') {
              textInputShowCalls++;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.textInput,
            null,
          );
          controller.dispose();
          focusNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DriverOtpBarsWidget(
                  controller: controller,
                  focusNode: focusNode,
                  autoFocus: true,
                  onCompleted: (code) => completedOtp = code,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isTrue);
        final beforeTapCalls = textInputShowCalls;
        await tester.tap(find.byType(DriverOtpBarsWidget));
        await tester.pump();
        expect(textInputShowCalls, greaterThan(beforeTapCalls));

        await tester.enterText(find.byType(TextField), '492817');
        await tester.pump();
        expect(completedOtp, '492817');
        expect(find.text('4'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      },
    );

    test('14. BookingRequestModel handles string IDs/nums and RequestsNotifier suppresses declined bookings', () async {
      final parsed = BookingRequestModel.fromJson({
        'id': '707',
        'booking_reference': 'BK-707',
        'pickup_address': 'RS Puram, Coimbatore',
        'pickup_latitude': 11.01,
        'pickup_longitude': 76.95,
        'estimated_eta_minutes': 4.0,
        'countdown_seconds': 90.0,
      });
      expect(parsed.id, 707);
      expect(parsed.estimatedEtaMinutes, 4);
      expect(parsed.countdownSeconds, 90);

      final container = ProviderContainer(
        overrides: [
          reverbServiceProvider.overrideWithValue(_TestReverbService()),
          requestsRepositoryProvider.overrideWithValue(
            _TestRequestsRepository([parsed]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(requestsProvider.notifier);
      notifier.simulateIncomingRequest(parsed);
      expect(container.read(requestsProvider).currentIncomingRequest?.id, 707);

      await notifier.declineRequest(707, reason: 'Busy');
      expect(container.read(requestsProvider).currentIncomingRequest, isNull);
    });

    test('15. NotificationsNotifier marks single and all notifications read safely', () async {
      final notifier = NotificationsNotifier();
      expect(notifier.state.any((n) => !n.isRead), isTrue);

      final unreadId = notifier.state.firstWhere((n) => !n.isRead).id;
      await notifier.markAsRead(unreadId);
      expect(notifier.state.firstWhere((n) => n.id == unreadId).isRead, isTrue);

      notifier.markAllAsRead();
      expect(notifier.state.every((n) => n.isRead), isTrue);

      notifier.clearAll();
      expect(notifier.state, isEmpty);
    });

    testWidgets(
      '16. DocumentUploadScreen with fromProfile pops back cleanly instead of resetting to PhoneLoginScreen',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(
                (ref) => _TestAuthNotifier(
                  DriverModel(
                    id: 1,
                    name: 'Test Pilot',
                    phone: '+919876543210',
                    email: 'pilot@liferoute.in',
                    emergencyContact: '+919800000000',
                    licenseNumber: 'TN01-2026-0001',
                    licenseExpiryDate: '2030-12-31',
                    verificationStatus: VerificationStatus.approved,
                    documentsUploaded: const {},
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DocumentUploadScreen(fromProfile: true),
                          ),
                        );
                      },
                      child: const Text('Open Docs'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Docs'));
        await tester.pumpAndSettle();
        expect(find.text('Save & Return to Profile'), findsOneWidget);

        await tester.tap(find.text('Save & Return to Profile'));
        await tester.pumpAndSettle();

        expect(find.text('Open Docs'), findsOneWidget);
        expect(find.byType(PhoneLoginScreen), findsNothing);
      },
    );

    test('17. DistanceUtils accurately calculates driving and polyline meters with zero-meter formatting', () {
      expect(DistanceUtils.formatDistance(0), '0 m');
      expect(DistanceUtils.formatDistance(850), '850 m');
      expect(DistanceUtils.formatDistance(2400), '2.4 km');

      final drivingMeters = DistanceUtils.calculateDrivingDistanceMeters(
        11.0000,
        76.9500,
        11.0200,
        76.9500,
      );
      expect(drivingMeters, greaterThan(2200));

      final polyMeters = DistanceUtils.calculatePolylineMeters(const [
        (lat: 11.0000, lng: 76.9500),
        (lat: 11.0100, lng: 76.9500),
        (lat: 11.0200, lng: 76.9500),
      ]);
      expect(polyMeters, inInclusiveRange(2100.0, 2400.0));
      expect(DistanceUtils.estimateEta(polyMeters), isNotEmpty);
    });

    test('18. Driver, Trip, and BookingRequest models have zero hardcoded default names or static distance', () {
      final driver = DriverModel.fromJson({});
      expect(driver.name, isEmpty);

      final trip = TripModel.fromJson({});
      expect(trip.patientName, anyOf(isNull, isEmpty));
      expect(trip.distanceRemainingMeters, 0.0);

      final request = BookingRequestModel.fromJson({});
      expect(request.patientName, anyOf(isNull, isEmpty));
      expect(request.distanceMeters, 0.0);
    });

    testWidgets(
      '19. PhoneLoginScreen has no top-right server button in AppBar actions',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(
                _FakeSecureStorageService(),
              ),
            ],
            child: const MaterialApp(home: PhoneLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no DNS / server button icon is in the top right corner
        expect(find.byIcon(Icons.dns_rounded), findsNothing);
        expect(find.text('Dispatch Server Connection'), findsNothing);
      },
    );

    test('20. RequestsNotifier restricts driver when booking was accepted by another ambulance', () async {
      final repo = _TestConflictRequestsRepository();
      final container = ProviderContainer(
        overrides: [requestsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(requestsProvider.notifier);
      final sample = BookingRequestModel.fromJson({
        'id': 77,
        'booking_reference': 'LR-EMG-0077',
        'patient_name': 'Kavitha Devi',
        'patient_phone': '+91 94444 33221',
        'pickup_address': 'Sector 4',
        'pickup_latitude': 11.0168,
        'pickup_longitude': 76.9558,
        'distance_meters': 1400.0,
      });

      notifier.simulateIncomingRequest(sample);
      expect(container.read(requestsProvider).currentIncomingRequest?.id, 77);

      // Attempting to accept a booking that another driver already accepted
      final accepted = await notifier.acceptRequest(77);
      expect(accepted, isFalse);
      expect(container.read(requestsProvider).currentIncomingRequest, isNull);
      expect(
        container.read(requestsProvider).conflictMessage,
        contains('already accepted by another ambulance'),
      );
    });

    test('21. AuthNotifier verifies password login and reset password for driver account', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _FakeSecureStorageService();
      final repo = _FakeAuthRepository(storage);
      final notifier = AuthNotifier(repo, storage);

      // Wrong password
      final wrongOk = await notifier.loginWithPassword(
        phone: '8428304510',
        password: 'wrong',
      );
      expect(wrongOk, isFalse);
      expect(notifier.state.errorMessage, contains('Incorrect password'));

      // Correct password
      final correctOk = await notifier.loginWithPassword(
        phone: '8428304510',
        password: 'secure123',
      );
      expect(correctOk, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.driver?.name, 'Muruganandam');

      // Reset password
      final resetOk = await notifier.resetPassword(
        phone: '8428304510',
        newPassword: 'newpassword123',
        confirmPassword: 'newpassword123',
      );
      expect(resetOk, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('22. Driver registration sets unauthenticated state and storage deduplicates trips', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _FakeSecureStorageService();
      final repo = _FakeAuthRepository(storage);
      final notifier = AuthNotifier(repo, storage);

      final registerOk = await notifier.register(
        name: 'New Driver',
        phone: '+919876543210',
        password: 'password123',
        email: 'driver@test.com',
        emergencyContact: '9876543211',
        licenseNumber: 'DL12345678',
        licenseExpiryDate: '2028-12-31',
        ambulanceRegNumber: 'TN 38 AB 1234',
        vehicleType: 'als',
        makeModel: 'Force Traveller',
        year: 2024,
        equipmentList: ['Oxygen', 'Defibrillator'],
        operatorAffiliation: '108 GVK EMRI',
        permitNumber: 'PERMIT123',
        permitExpiryDate: '2028-12-31',
        insurancePolicyNumber: 'INS123',
        insuranceExpiryDate: '2028-12-31',
      );

      expect(registerOk, isTrue);
      // New driver must be unauthenticated upon registration so they go to PhoneLoginScreen!
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.driver?.name, 'New Driver');

      // Verify trip deduplication in storage
      final tripMap = {
        'id': 1001,
        'booking_reference': 'BK-1001',
        'status': 'completed',
        'earnings': 650.0,
      };
      await storage.saveCompletedTrip(tripMap);
      await storage.saveCompletedTrip(tripMap);
      final completed = await storage.getCompletedTrips();
      expect(completed.length, 1);
      expect(completed.first['booking_reference'], 'BK-1001');
    });
  });
}

class _TestReverbService extends ReverbService {
  @override
  Future<void> connect(int driverId) async {}

  @override
  Future<void> disconnect() async {}
}

class _TestRequestsRepository extends RequestsRepository {
  final List<BookingRequestModel> _pending;
  _TestRequestsRepository(this._pending)
    : super(DioClient(SecureStorageService()));

  @override
  Future<List<BookingRequestModel>> getPendingRequests() async => _pending;

  @override
  Future<void> declineBooking(int bookingId, {String? reason}) async {}

  @override
  Future<TripModel> acceptBooking(
    int bookingId, {
    BookingRequestModel? originalRequest,
  }) {
    throw UnimplementedError();
  }
}

class _TestConflictRequestsRepository extends RequestsRepository {
  _TestConflictRequestsRepository() : super(DioClient(SecureStorageService()));

  @override
  Future<List<BookingRequestModel>> getPendingRequests() async => [];

  @override
  Future<void> declineBooking(int bookingId, {String? reason}) async {}

  @override
  Future<TripModel> acceptBooking(
    int bookingId, {
    BookingRequestModel? originalRequest,
  }) async {
    throw BookingAlreadyClaimedException(
      'This emergency booking was already accepted by another ambulance or claimed by dispatch.',
    );
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(DriverModel driver)
    : super(
        AuthRepository(
          DioClient(SecureStorageService()),
          SecureStorageService(),
        ),
        SecureStorageService(),
      ) {
    state = AuthState(status: AuthStatus.authenticated, driver: driver);
  }

  @override
  Future<void> checkInitialAuth() async {}
}
