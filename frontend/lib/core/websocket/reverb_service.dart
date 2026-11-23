import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

/// Real-time WebSocket service (Reverb / Pusher JSON protocol) for dispatch and trip updates
class ReverbService {
  bool _isConnected = false;
  int? _subscribedDriverId;
  String? _subscribedBookingChannel;
  String? _activeWsUrl;
  WebSocketChannel? _directChannel;
  StreamSubscription<dynamic>? _directSubscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Stream controllers for app events
  final _bookingRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _bookingCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _bookingClaimedByOtherController = StreamController<Map<String, dynamic>>.broadcast();
  final _destinationChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _dispatcherMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  ReverbService();

  // Stream getters
  Stream<Map<String, dynamic>> get onBookingRequest => _bookingRequestController.stream;
  Stream<Map<String, dynamic>> get onBookingCancelled => _bookingCancelledController.stream;
  Stream<Map<String, dynamic>> get onBookingClaimedByOther => _bookingClaimedByOtherController.stream;
  Stream<Map<String, dynamic>> get onDestinationChanged => _destinationChangedController.stream;
  Stream<Map<String, dynamic>> get onDispatcherMessage => _dispatcherMessageController.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  String _buildWsUrl() {
    final isSecureWeb = kIsWeb && Uri.base.scheme == 'https';
    final useTls = ApiConstants.reverbScheme == 'https' ||
        isSecureWeb ||
        ApiConstants.reverbHost.contains('trycloudflare.com') ||
        ApiConstants.reverbPort == 443;
    final scheme = useTls ? 'wss' : 'ws';
    final host = ApiConstants.reverbHost;
    final port = ApiConstants.reverbPort;
    if (useTls && (port == 443 || port == 80)) {
      return '$scheme://$host';
    }
    return '$scheme://$host:$port';
  }

  /// Connect to WebSocket server across both Web and Mobile
  Future<void> connect(int driverId) async {
    final wsUrl = _buildWsUrl();
    if (_isConnected &&
        _directChannel != null &&
        _subscribedDriverId == driverId &&
        _activeWsUrl == wsUrl) {
      return;
    }
    _subscribedDriverId = driverId;
    _connectDirectSocket(driverId);
  }

  /// Reconnect active WebSocket stream (e.g. after changing dispatch server host)
  Future<void> reconnectIfActive({bool force = false}) async {
    if (_subscribedDriverId == null) return;
    final wsUrl = _buildWsUrl();
    if (!force &&
        _isConnected &&
        _directChannel != null &&
        _activeWsUrl == wsUrl) {
      return;
    }
    _connectDirectSocket(_subscribedDriverId!);
  }

  void _connectDirectSocket(int driverId) {
    try {
      final wsUrl = _buildWsUrl();
      debugPrint('🔌 [ReverbService] Connecting WebSocket: $wsUrl');
      _reconnectTimer?.cancel();
      _pingTimer?.cancel();
      final oldSubscription = _directSubscription;
      final oldChannel = _directChannel;
      _directSubscription = null;
      _directChannel = null;
      try {
        oldSubscription?.cancel();
      } catch (_) {}
      try {
        oldChannel?.sink.close();
      } catch (_) {}

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _directChannel = channel;
      _activeWsUrl = wsUrl;

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      debugPrint('✅ [ReverbService] WebSocket connected to $wsUrl');

      // Keepalive heartbeat every 15s prevents NAT / mobile radio sleep drops
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!identical(_directChannel, channel)) return;
        try {
          channel.sink.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
        } catch (_) {
          if (!identical(_directChannel, channel)) return;
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleDirectReconnect(driverId);
        }
      });

      // Subscribe to driver channel and broadcast channel
      final driverChannel = ApiConstants.driverPrivateChannel(driverId);
      channel.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': driverChannel},
      }));
      channel.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': ApiConstants.emergencyBroadcastChannel},
      }));

      if (_subscribedBookingChannel != null) {
        channel.sink.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': _subscribedBookingChannel},
        }));
      }

      _directSubscription = channel.stream.listen(
        (data) {
          if (!identical(_directChannel, channel)) return;
          try {
            final decoded = jsonDecode(data.toString());
            final parsed = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
            final eventName = parsed['event'] as String? ?? '';
            dynamic eventData = parsed['data'];
            if (eventData is String) {
              try {
                eventData = jsonDecode(eventData);
              } catch (_) {}
            }
            if (eventData is Map) {
              _routeEvent(eventName, Map<String, dynamic>.from(eventData));
            } else if (parsed.containsKey('id') || parsed.containsKey('booking_reference')) {
              _routeEvent(eventName, parsed);
            }
          } catch (e) {
            debugPrint('Error parsing WS data: $e');
          }
        },
        onDone: () {
          if (!identical(_directChannel, channel)) return;
          debugPrint('❌ [ReverbService] WebSocket closed. Reconnecting in 5s...');
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleDirectReconnect(driverId);
        },
        onError: (e) {
          if (!identical(_directChannel, channel)) return;
          debugPrint('⚠️ [ReverbService] WebSocket error: $e');
          _isConnected = false;
          _connectionStateController.add(false);
          _scheduleDirectReconnect(driverId);
        },
      );
    } catch (e) {
      debugPrint('⚠️ [ReverbService] WebSocket connect error: $e');
      _isConnected = false;
      _connectionStateController.add(false);
      _scheduleDirectReconnect(driverId);
    }
  }

  int _reconnectAttempts = 0;

  void _scheduleDirectReconnect(int driverId) {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 2) ? 1 : ((_reconnectAttempts <= 4) ? 2 : 4);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
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
      _directChannel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName},
      }));
    } catch (_) {}
  }

  /// Subscribe to active booking channel for trip changes (e.g. cancellation, hospital change)
  Future<void> subscribeToBookingChannel(int bookingId) async {
    await unsubscribeBookingChannel();
    final channelName = ApiConstants.bookingPrivateChannel(bookingId);
    _subscribedBookingChannel = channelName;
    try {
      _directChannel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName},
      }));
    } catch (_) {}
  }

  /// Unsubscribe active booking channel when trip completes or cancels
  Future<void> unsubscribeBookingChannel() async {
    if (_subscribedBookingChannel != null) {
      try {
        _directChannel?.sink.add(jsonEncode({
          'event': 'pusher:unsubscribe',
          'data': {'channel': _subscribedBookingChannel},
        }));
      } catch (_) {}
      _subscribedBookingChannel = null;
    }
  }

  void _routeEvent(String eventName, Map<String, dynamic> data) {
    switch (eventName) {
      case 'BookingRequested':
      case 'new-booking-request':
      case 'NewEmergencyIncident':
        _bookingRequestController.add(data);
        break;

      case 'BookingCancelled':
      case 'TripCancelled':
      case 'booking-cancelled':
      case 'trip-cancelled':
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

      case 'TripChatMessage':
      case 'trip-chat-message':
        _chatMessageController.add(data);
        break;

      case 'pusher:pong':
      case 'pusher:connection_established':
      case 'pusher_internal:subscription_succeeded':
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
        } else if (eventName.contains('Chat')) {
          _chatMessageController.add(data);
        }
        break;
    }
  }

  /// Disconnect and cleanup subscriptions on logout
  Future<void> disconnect() async {
    _subscribedDriverId = null;
    _activeWsUrl = null;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await unsubscribeBookingChannel();
    final sub = _directSubscription;
    final ch = _directChannel;
    _directSubscription = null;
    _directChannel = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await ch?.sink.close();
    } catch (_) {}
    _isConnected = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    _subscribedDriverId = null;
    _activeWsUrl = null;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try {
      _directSubscription?.cancel();
    } catch (_) {}
    try {
      _directChannel?.sink.close();
    } catch (_) {}
    _directSubscription = null;
    _directChannel = null;
    _bookingRequestController.close();
    _bookingCancelledController.close();
    _bookingClaimedByOtherController.close();
    _destinationChangedController.close();
    _dispatcherMessageController.close();
    _chatMessageController.close();
    _connectionStateController.close();
  }
}
