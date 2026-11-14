import 'package:flutter_test/flutter_test.dart';
import 'package:liferoute_driver/core/services/driver_notification_service.dart';
import 'package:liferoute_driver/features/notifications/models/app_notification_model.dart';
import 'package:liferoute_driver/features/notifications/screens/notifications_screen.dart';
import 'package:liferoute_driver/features/requests/models/booking_request_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Notification Service Tests', () {
    test('DriverNotificationService initializes and fires alerts without unhandled errors', () async {
      final service = DriverNotificationService.instance;
      await service.initialize();

      // Dispatch alert
      await service.showDispatchAlert(
        id: 9991,
        title: '🚨 Test Emergency Dispatch',
        body: 'Patient in critical condition at MG Road',
      );

      // System alert
      await service.showSystemAlert(
        id: 9992,
        title: '🛰️ Fleet Telematics Active',
        body: 'GPS telemetry synchronized',
      );

      // Chat notification
      await service.showChatNotification(
        id: 9993,
        title: '💬 Message from Patient',
        body: 'Ambulance is near entrance',
      );

      // Cancel alerts
      await service.cancel(9991);
      await service.cancelAll();
    });

    test('NotificationsNotifier triggers notification service on addBookingAlert and addAlert', () {
      final notifier = NotificationsNotifier();
      final initialCount = notifier.state.length;

      final testReq = BookingRequestModel(
        id: 88812,
        bookingReference: 'BK-TEST-88',
        patientName: 'Karthik Rao',
        emergencyCategory: 'Cardiac Emergency',
        pickupAddress: 'Koramangala 4th Block',
        pickupLatitude: 12.9352,
        pickupLongitude: 77.6245,
        essentialInstructions: 'Keep oxygen cylinder ready',
        createdAt: DateTime.now(),
      );

      notifier.addBookingAlert(testReq);
      expect(notifier.state.length, initialCount + 1);
      expect(notifier.state.first.id, 88812);
      expect(notifier.state.first.type, NotificationType.newBooking);

      notifier.addAlert(
        title: '⚠️ Dispatch Test',
        message: 'Test message body',
        type: NotificationType.systemAlert,
      );
      expect(notifier.state.length, initialCount + 2);
    });
  });
}
