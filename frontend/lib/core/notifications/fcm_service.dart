import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Message ID: ${message.messageId}, Type: ${message.data['type']}');
}

/// Firebase Cloud Messaging service for push dispatch alerts
class FcmService {
  final DioClient _dioClient;
  final SecureStorageService _storageService;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final _fcmNotificationController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationReceived => _fcmNotificationController.stream;

  FcmService(this._dioClient, this._storageService);

  /// Initialize FCM, request permissions, and register token
  Future<void> init() async {
    try {
      // Notification permissions (critical for emergency alerts)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Title: ${message.notification?.title}');
        _fcmNotificationController.add(message);
      });

      // Handle notification opened app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM Opened App] Payload: ${message.data}');
        _fcmNotificationController.add(message);
      });

      // Fetch and upload token
      await _syncToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        await _registerTokenWithBackend(newToken);
      });
    } catch (e) {
      debugPrint('[FCM] Init error: $e');
    }
  }

  Future<void> _syncToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _storageService.saveFcmToken(token);
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Token fetch error: $e');
    }
  }

  /// Sends device token to Laravel backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final authToken = await _storageService.getAuthToken();
      if (authToken == null) return; // Wait until authenticated

      await _dioClient.post(
        ApiConstants.updateFcmToken,
        data: {
          'fcm_token': token,
          'device_type': defaultTargetPlatform.name.toLowerCase(),
        },
      );
      debugPrint('[FCM] Token synced successfully with Laravel backend');
    } catch (e) {
      debugPrint('[FCM] Failed to sync token with backend: $e');
    }
  }

  void dispose() {
    _fcmNotificationController.close();
  }
}
