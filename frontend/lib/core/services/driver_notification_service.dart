import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System-level local and push notification service for LifeRoute Ambulance Driver
class DriverNotificationService {
  DriverNotificationService._();
  static final DriverNotificationService instance = DriverNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  static const String _dispatchChannelId = 'emergency_dispatch_channel';
  static const String _dispatchChannelName = 'Emergency Ambulance Dispatches';
  static const String _dispatchChannelDesc = 'High-priority notifications for incoming emergency dispatches';

  static const String _systemChannelId = 'system_alerts_channel';
  static const String _systemChannelName = 'LifeRoute System & Fleet Alerts';
  static const String _systemChannelDesc = 'Fleet status, shift updates, and system notifications';

  static const String _chatChannelId = 'patient_chat_channel';
  static const String _chatChannelName = 'Patient & Dispatch Chat';
  static const String _chatChannelDesc = 'Urgent messages from patients and emergency dispatchers';

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // On Android 13+ (API 33+), request POST_NOTIFICATIONS runtime permission
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('🔔 [DriverNotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('ℹ️ [DriverNotificationService] Local notifications platform channel inactive: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 [DriverNotificationService] Notification tapped: ${response.payload}');
  }

  /// Show high-priority emergency dispatch notification (plays sound, vibrates, heads-up)
  Future<void> showDispatchAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _dispatchChannelId,
        _dispatchChannelName,
        channelDescription: _dispatchChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        ticker: '🚨 Emergency Ambulance Dispatch',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ [DriverNotificationService] showDispatchAlert error: $e');
    }
  }

  /// Show system or fleet notification
  Future<void> showSystemAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _systemChannelId,
        _systemChannelName,
        channelDescription: _systemChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ [DriverNotificationService] showSystemAlert error: $e');
    }
  }

  /// Show patient chat notification
  Future<void> showChatNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ [DriverNotificationService] showChatNotification error: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancel(int id) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
