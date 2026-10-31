import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Laravel Reverb WebSocket Service for real-time dispatch and trip updates
class ReverbService {
  final SecureStorageService _storageService;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _isConnected = false;
  int? _subscribedDriverId;
  String? _subscribedBookingChannel;

  // Stream controllers for app events
  final _bookingRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _bookingCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _bookingClaimedByOtherController = StreamController<Map<String, dynamic>>.broadcast();
  final _destinationChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _dispatcherMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  ReverbService(this._storageService);

  // Stream getters
  Stream<Map<String, dynamic>> get onBookingRequest => _bookingRequestController.stream;
  Stream<Map<String, dynamic>> get onBookingCancelled => _bookingCancelledController.stream;
  Stream<Map<String, dynamic>> get onBookingClaimedByOther => _bookingClaimedByOtherController.stream;
  Stream<Map<String, dynamic>> get onDestinationChanged => _destinationChangedController.stream;
  Stream<Map<String, dynamic>> get onDispatcherMessage => _dispatcherMessageController.stream;
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  /// Connect to Laravel Reverb WebSocket Server
  Future<void> connect(int driverId) async {
    final token = await _storageService.getAuthToken();
    if (token == null) {
      debugPrint('[ReverbService] Cannot connect: missing Sanctum auth token');
      return;
    }

    try {
      await _pusher.init(
        apiKey: ApiConstants.reverbAppKey,
        cluster: 'mt1',
        useTLS: true,
        authEndpoint: '${ApiConstants.defaultBaseUrl}${ApiConstants.reverbAuthEndpoint}',
        onAuthorizer: (channelName, socketId, options) async {
          // Sanctum authorization headers for private channel authorization
          return {
            "auth": "",
            "channel_data": "",
            "shared_secret": "",
            "headers": {
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            }
          };
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('[ReverbService] State: $previousState -> $currentState');
          _isConnected = (currentState.toLowerCase() == 'connected');
          _connectionStateController.add(_isConnected);
        },
        onError: (message, code, error) {
          debugPrint('[ReverbService] Error: $message ($code)');
        },
        onSubscriptionSucceeded: (channelName, data) {
          debugPrint('[ReverbService] Subscribed to $channelName');
        },
        onEvent: (event) {
          _handleIncomingEvent(event);
        },
      );

      await _pusher.connect();
      await subscribeToDriverChannel(driverId);
    } catch (e) {
      debugPrint('[ReverbService] Connection error: $e');
    }
  }

  /// Subscribe to driver-specific private channel for incoming booking requests
  Future<void> subscribeToDriverChannel(int driverId) async {
    _subscribedDriverId = driverId;
    final channelName = ApiConstants.driverPrivateChannel(driverId);
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      debugPrint('[ReverbService] Subscribe driver channel error: $e');
    }
  }

  /// Subscribe to active booking channel for trip changes (e.g. cancellation, hospital change)
  Future<void> subscribeToBookingChannel(int bookingId) async {
    await unsubscribeBookingChannel();
    final channelName = ApiConstants.bookingPrivateChannel(bookingId);
    _subscribedBookingChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      debugPrint('[ReverbService] Subscribe booking channel error: $e');
    }
  }

  /// Unsubscribe active booking channel when trip completes or cancels
  Future<void> unsubscribeBookingChannel() async {
    if (_subscribedBookingChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _subscribedBookingChannel!);
      } catch (_) {}
      _subscribedBookingChannel = null;
    }
  }

  /// Parse and route Reverb broadcast events to corresponding streams
  void _handleIncomingEvent(PusherEvent event) {
    debugPrint('[ReverbService] Event: ${event.eventName} on ${event.channelName}');
    
    Map<String, dynamic> data = {};
    if (event.data != null) {
      try {
        if (event.data is String) {
          data = jsonDecode(event.data!) as Map<String, dynamic>;
        } else if (event.data is Map) {
          data = Map<String, dynamic>.from(event.data as Map);
        }
      } catch (e) {
        debugPrint('[ReverbService] Failed to parse event payload: $e');
      }
    }

    switch (event.eventName) {
      case 'BookingRequested':
      case 'new-booking-request':
        _bookingRequestController.add(data);
        break;

      case 'BookingCancelled':
      case 'booking-cancelled':
        _bookingCancelledController.add(data);
        break;

      case 'BookingAcceptedByOther':
      case 'booking-claimed':
        _bookingClaimedByOtherController.add(data);
        break;

      case 'DestinationChanged':
      case 'hospital-updated':
        _destinationChangedController.add(data);
        break;

      case 'DispatcherMessage':
      case 'dispatcher-alert':
        _dispatcherMessageController.add(data);
        break;

      default:
        // Handle custom Laravel event namespaces like App\\Events\\NewBookingRequest
        if (event.eventName.contains('BookingRequested') || event.eventName.contains('NewBooking')) {
          _bookingRequestController.add(data);
        } else if (event.eventName.contains('Cancelled')) {
          _bookingCancelledController.add(data);
        } else if (event.eventName.contains('Claimed') || event.eventName.contains('Taken')) {
          _bookingClaimedByOtherController.add(data);
        } else if (event.eventName.contains('Destination')) {
          _destinationChangedController.add(data);
        } else if (event.eventName.contains('Dispatcher')) {
          _dispatcherMessageController.add(data);
        }
        break;
    }
  }

  /// Disconnect and cleanup subscriptions on logout
  Future<void> disconnect() async {
    try {
      if (_subscribedDriverId != null) {
        await _pusher.unsubscribe(
          channelName: ApiConstants.driverPrivateChannel(_subscribedDriverId!),
        );
      }
      await unsubscribeBookingChannel();
      await _pusher.disconnect();
    } catch (_) {}
    _isConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    _bookingRequestController.close();
    _bookingCancelledController.close();
    _bookingClaimedByOtherController.close();
    _destinationChangedController.close();
    _dispatcherMessageController.close();
    _connectionStateController.close();
  }
}
