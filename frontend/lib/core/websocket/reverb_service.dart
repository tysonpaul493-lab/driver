import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Laravel Reverb WebSocket Service for real-time dispatch and trip updates
class ReverbService {
  final SecureStorageService _storageService;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _isConnected = false;
  int? _subscribedDriverId;
  String? _subscribedBookingChannel;
  WebSocketChannel? _directChannel;
  Timer? _reconnectTimer;

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
    _subscribedDriverId = driverId;
    final token = await _storageService.getAuthToken() ?? '1|demo_driver_token';

    // 1. Try Pusher client
    try {
      final isHttps = ApiConstants.reverbScheme.toLowerCase() == 'https';
      await _pusher.init(
        apiKey: ApiConstants.reverbAppKey,
        cluster: 'mt1',
        useTLS: isHttps,
        authEndpoint: '${ApiConstants.defaultBaseUrl}${ApiConstants.reverbAuthEndpoint}',
        onAuthorizer: (channelName, socketId, options) async {
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
          debugPrint('[ReverbService Pusher] State: $previousState -> $currentState');
          _isConnected = (currentState.toLowerCase() == 'connected');
          _connectionStateController.add(_isConnected);
        },
        onError: (message, code, error) {
          debugPrint('[ReverbService Pusher] Error: $message ($code)');
        },
        onSubscriptionSucceeded: (channelName, data) {
          debugPrint('[ReverbService Pusher] Subscribed to $channelName');
        },
        onEvent: (event) {
          _handlePusherEvent(event);
        },
      );

      await _pusher.connect();
      await subscribeToDriverChannel(driverId);
    } catch (e) {
      debugPrint('[ReverbService] Pusher plugin error, using direct WebSocket fallback: $e');
    }

    // 2. Also start universal direct WebSocket connection for instant local reliability
    _connectDirectSocket(driverId);
  }

  void _connectDirectSocket(int driverId) async {
    try {
      final wsUrl = 'ws://${ApiConstants.reverbHost}:${ApiConstants.reverbPort}';
      debugPrint('🔌 [ReverbService] Connecting direct WebSocket: $wsUrl');
      try {
        _directChannel?.sink.close();
      } catch (_) {}
      _directChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _isConnected = true;
      _connectionStateController.add(true);
      debugPrint('✅ [ReverbService] Direct WebSocket connected to $wsUrl');

      // Subscribe to driver channel and broadcast channel
      final driverChannel = ApiConstants.driverPrivateChannel(driverId);
      _directChannel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': driverChannel},
      }));
      _directChannel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': ApiConstants.emergencyBroadcastChannel},
      }));

      if (_subscribedBookingChannel != null) {
        _directChannel?.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': _subscribedBookingChannel},
        }));
      }

      _directChannel?.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            final eventName = parsed['event'] as String? ?? '';
            dynamic eventData = parsed['data'];
            if (eventData is String) {
              try {
                eventData = jsonDecode(eventData);
              } catch (_) {}
            }
            if (eventData is Map<String, dynamic>) {
              _routeEvent(eventName, eventData);
            } else if (parsed.containsKey('id') || parsed.containsKey('booking_reference')) {
              _routeEvent(eventName, parsed);
            }
          } catch (e) {
            debugPrint('Error parsing direct WS data: $e');
          }
        },
        onDone: () {
          debugPrint('❌ [ReverbService] Direct WebSocket closed. Reconnecting in 5s...');
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleDirectReconnect(driverId);
        },
        onError: (e) {
          debugPrint('⚠️ [ReverbService] Direct WebSocket error: $e');
          _scheduleDirectReconnect(driverId);
        },
      );
    } catch (e) {
      debugPrint('⚠️ [ReverbService] Direct WebSocket connect error: $e');
      _scheduleDirectReconnect(driverId);
    }
  }

  void _scheduleDirectReconnect(int driverId) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_subscribedDriverId != null) {
        _connectDirectSocket(driverId);
      }
    });
  }

  /// Subscribe to driver-specific private channel for incoming booking requests
  Future<void> subscribeToDriverChannel(int driverId) async {
    _subscribedDriverId = driverId;
    final channelName = ApiConstants.driverPrivateChannel(driverId);
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (_) {}

    _directChannel?.sink.add(jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    }));
  }

  /// Subscribe to active booking channel for trip changes (e.g. cancellation, hospital change)
  Future<void> subscribeToBookingChannel(int bookingId) async {
    await unsubscribeBookingChannel();
    final channelName = ApiConstants.bookingPrivateChannel(bookingId);
    _subscribedBookingChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (_) {}

    _directChannel?.sink.add(jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    }));
  }

  /// Unsubscribe active booking channel when trip completes or cancels
  Future<void> unsubscribeBookingChannel() async {
    if (_subscribedBookingChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _subscribedBookingChannel!);
      } catch (_) {}

      _directChannel?.sink.add(jsonEncode({
        'event': 'pusher:unsubscribe',
        'data': {'channel': _subscribedBookingChannel},
      }));
      _subscribedBookingChannel = null;
    }
  }

  void _handlePusherEvent(PusherEvent event) {
    debugPrint('[ReverbService Pusher] Event: ${event.eventName} on ${event.channelName}');
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
    _routeEvent(event.eventName, data);
  }

  void _routeEvent(String eventName, Map<String, dynamic> data) {
    switch (eventName) {
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
        if (eventName.contains('BookingRequested') || eventName.contains('NewBooking')) {
          _bookingRequestController.add(data);
        } else if (eventName.contains('Cancelled')) {
          _bookingCancelledController.add(data);
        } else if (eventName.contains('Claimed') || eventName.contains('Taken')) {
          _bookingClaimedByOtherController.add(data);
        } else if (eventName.contains('Destination')) {
          _destinationChangedController.add(data);
        } else if (eventName.contains('Dispatcher')) {
          _dispatcherMessageController.add(data);
        }
        break;
    }
  }

  /// Disconnect and cleanup subscriptions on logout
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    try {
      if (_subscribedDriverId != null) {
        await _pusher.unsubscribe(
          channelName: ApiConstants.driverPrivateChannel(_subscribedDriverId!),
        );
      }
      await unsubscribeBookingChannel();
      await _pusher.disconnect();
    } catch (_) {}

    try {
      _directChannel?.sink.close();
    } catch (_) {}

    _isConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    try {
      _directChannel?.sink.close();
    } catch (_) {}
    _bookingRequestController.close();
    _bookingCancelledController.close();
    _bookingClaimedByOtherController.close();
    _destinationChangedController.close();
    _dispatcherMessageController.close();
    _connectionStateController.close();
  }
}
