import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/driver_notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../requests/models/booking_request_model.dart';
import '../../requests/providers/requests_provider.dart';
import '../models/app_notification_model.dart';

class NotificationsNotifier extends StateNotifier<List<AppNotificationModel>> {
  final DioClient? _dioClient;

  NotificationsNotifier([this._dioClient]) : super(_defaultNotifications) {
    if (_dioClient != null) {
      fetchFromBackend();
    }
  }

  static final List<AppNotificationModel> _defaultNotifications = [
    AppNotificationModel(
      id: 1,
      title: '🚨 Emergency Dispatch Assigned',
      message: 'New Critical (Red Triage) emergency dispatch BK-94821 received from Indiranagar.',
      type: NotificationType.newBooking,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      isRead: false,
    ),
    AppNotificationModel(
      id: 2,
      title: '🏥 Trauma Center Clearance',
      message: 'City Trauma Center cleared Bay 3 & ICU ventilator for incoming cardiac patient.',
      type: NotificationType.dispatcherInstruction,
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      isRead: false,
    ),
    AppNotificationModel(
      id: 3,
      title: '🛰️ System Alert: GPS Telemetry Active',
      message: 'High-precision GPS telemetry locked at 15.5 zoom. Driver coordinates synchronized with central dispatch.',
      type: NotificationType.systemAlert,
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      isRead: true,
    ),
    AppNotificationModel(
      id: 4,
      title: '🔄 Hospital Re-route Advisory',
      message: 'Patient in BK-89241 re-routed to Apollo Emergency due to emergency ICU bed clearance.',
      type: NotificationType.destinationChanged,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    AppNotificationModel(
      id: 5,
      title: '⚡ System Alert: Driver Online Status Active',
      message: 'Ambulance Unit is registered ONLINE and visible to regional 108/112 dispatchers.',
      type: NotificationType.systemAlert,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: true,
    ),
    AppNotificationModel(
      id: 6,
      title: '🛡️ Pilot Compliance Verified',
      message: 'Commercial driving permit, fitness certification, and BLS badge successfully approved by transport authority.',
      type: NotificationType.supportMessage,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    AppNotificationModel(
      id: 7,
      title: '⚠️ Dispatch Alert: Booking Claimed',
      message: 'Booking request BK-87110 was accepted by nearest Ambulance Unit AMB-042.',
      type: NotificationType.acceptedByOther,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      isRead: true,
    ),
  ];

  Future<void> fetchFromBackend() async {
    final dio = _dioClient;
    if (dio == null) return;
    try {
      final response = await dio.get(ApiConstants.notifications);
      final list = response['notifications'] as List? ?? [];
      if (list.isEmpty) return;

      final fetched = <AppNotificationModel>[];
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final typeStr = raw['type']?.toString().toLowerCase() ?? '';
        final notifType =
            typeStr.contains('dispatch') || typeStr.contains('booking')
            ? NotificationType.newBooking
            : (typeStr.contains('hospital') || typeStr.contains('route')
                  ? NotificationType.destinationChanged
                  : NotificationType.systemAlert);
        fetched.add(
          AppNotificationModel(
            id:
                int.tryParse(raw['id']?.toString() ?? '') ??
                DateTime.now().millisecondsSinceEpoch,
            title: raw['title']?.toString() ?? 'Dispatch Update',
            message: raw['message']?.toString() ?? '',
            type: notifType,
            timestamp:
                DateTime.tryParse(raw['created_at']?.toString() ?? '') ??
                DateTime.now(),
            isRead: raw['is_read'] == true,
          ),
        );
      }
      if (fetched.isNotEmpty) {
        final existingIds = state.map((n) => n.id).toSet();
        final merged = [
          ...fetched.where((n) => !existingIds.contains(n.id)),
          ...state,
        ];
        merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = merged;
      }
    } catch (_) {}
  }

  Future<void> markAsRead(int id) async {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    final dio = _dioClient;
    if (dio != null) {
      try {
        await dio.post(
          ApiConstants.markNotificationRead.replaceAll('{id}', id.toString()),
        );
      } catch (_) {}
    }
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() {
    state = [];
  }

  void addBookingAlert(BookingRequestModel req) {
    if (state.any(
      (n) =>
          n.id == req.id ||
          (req.bookingReference.isNotEmpty &&
              n.message.contains(req.bookingReference)),
    )) {
      return;
    }

    final alert = AppNotificationModel(
      id: req.id,
      title:
          '🚨 Emergency Dispatch: ${req.patientName ?? "Patient"} (${req.bookingReference})',
      message:
          'Emergency ${req.emergencyCategory} at ${req.pickupAddress}.\nPatient Phone: ${req.patientPhone ?? "Contact not recorded"}\nDestination: ${req.destinationHospital ?? "Nearest Emergency Hospital"}\nNotes: ${req.essentialInstructions}',
      type: NotificationType.newBooking,
      timestamp: DateTime.now(),
      isRead: false,
      request: req,
    );
    state = [alert, ...state];

    DriverNotificationService.instance.showDispatchAlert(
      id: req.id,
      title: '🚨 Emergency Dispatch: ${req.patientName ?? "Patient"}',
      body: '${req.emergencyCategory} at ${req.pickupAddress}',
      payload: req.id.toString(),
    );
  }

  void addAlert({
    required String title,
    required String message,
    required NotificationType type,
  }) {
    final alertId = DateTime.now().millisecondsSinceEpoch % 100000;
    final alert = AppNotificationModel(
      id: alertId,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
    );
    state = [alert, ...state];

    DriverNotificationService.instance.showSystemAlert(
      id: alertId,
      title: title,
      body: message,
    );
  }

  void triggerTestSystemAlert() {
    addAlert(
      title: '🛰️ Live System Diagnostic: OK',
      message: 'All vehicle telematics, live dispatch channels, and hospital emergency relays are operating with 100% signal integrity.',
      type: NotificationType.systemAlert,
    );
  }

  void triggerTestDispatchAlert() {
    addAlert(
      title: '🚨 Test Emergency Dispatch Broadcast',
      message: 'Emergency central has broadcasted priority green corridor clearance along Inner Ring Road.',
      type: NotificationType.dispatcherInstruction,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotificationModel>>((
      ref,
    ) {
      final dio = ref.watch(dioClientProvider);
      return NotificationsNotifier(dio);
    });

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';

  void _showAlertDetailsDialog(AppNotificationModel notif) {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);
    final req = notif.request;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: notif.iconColor.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notif.iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(notif.icon, color: notif.iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notif.categoryLabel.toUpperCase(),
                style: TextStyle(
                  color: notif.iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notif.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (req != null) ...[
                // User Details Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: AppColors.ambulanceTeal,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Patient: ${req.patientName ?? "Emergency Patient"}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: AppColors.statusGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            req.patientPhone ?? 'Contact not recorded',
                            style: const TextStyle(
                              color: AppColors.ambulanceTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.emergencyRed,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pickup: ${req.pickupAddress}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (req.pickupLandmark != null &&
                          req.pickupLandmark!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              color: AppColors.alertOrange,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Landmark: ${req.pickupLandmark}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_hospital,
                            color: AppColors.statusGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hospital: ${req.destinationHospital ?? "Nearest Trauma Center"}',
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services_rounded,
                            color: AppColors.alertOrange,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Emergency: ${req.emergencyCategory}',
                            style: const TextStyle(
                              color: AppColors.alertOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                notif.message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppDateUtils.formatDateTime(notif.timestamp),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'DISMISS',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (req != null)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(requestsProvider.notifier).acceptRequest(req.id);
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'ACCEPT BOOKING',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    final filtered = notifications.where((n) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Dispatch') {
        return n.type == NotificationType.newBooking ||
            n.type == NotificationType.acceptedByOther ||
            n.type == NotificationType.userCancelled ||
            n.type == NotificationType.bookingExpired;
      }
      if (_selectedFilter == 'System') {
        return n.type == NotificationType.systemAlert;
      }
      if (_selectedFilter == 'Hospital') {
        return n.type == NotificationType.destinationChanged ||
            n.type == NotificationType.dispatcherInstruction;
      }
      return true;
    }).toList();

    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Alerts & Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.cardDark,
            onSelected: (val) {
              if (val == 'mark_read') {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              } else if (val == 'test_sys') {
                ref
                    .read(notificationsProvider.notifier)
                    .triggerTestSystemAlert();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test System Alert generated!')),
                );
              } else if (val == 'test_dispatch') {
                ref
                    .read(notificationsProvider.notifier)
                    .triggerTestDispatchAlert();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test Dispatch Alert generated!'),
                  ),
                );
              } else if (val == 'clear') {
                ref.read(notificationsProvider.notifier).clearAll();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: AppColors.ambulanceTeal,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Mark All as Read',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_sys',
                child: Row(
                  children: [
                    Icon(
                      Icons.phonelink_setup_rounded,
                      size: 18,
                      color: Color(0xFF64B5F6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Trigger Test System Alert',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_dispatch',
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: AppColors.ambulanceTeal,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Trigger Test Dispatch Alert',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.emergencyRed,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear All Alerts',
                      style: TextStyle(color: AppColors.emergencyRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceDark,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', notifications.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'System',
                    notifications
                        .where((n) => n.type == NotificationType.systemAlert)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Dispatch',
                    notifications
                        .where((n) => n.categoryLabel == 'Dispatch')
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Hospital',
                    notifications
                        .where((n) => n.categoryLabel == 'Hospital & Route')
                        .length,
                  ),
                ],
              ),
            ),
          ),

          // Notification List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 54,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No alerts found in $_selectedFilter category.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(notificationsProvider.notifier)
                                .triggerTestSystemAlert();
                          },
                          icon: const Icon(Icons.add_alert_rounded, size: 18),
                          label: const Text('Add Test Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ambulanceTeal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          enableFeedback: true,
                          splashColor: notif.iconColor.withValues(alpha: 0.15),
                          highlightColor: notif.iconColor.withValues(
                            alpha: 0.08,
                          ),
                          onTap: () => _showAlertDetailsDialog(notif),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: notif.isRead
                                    ? AppColors.borderDark
                                    : notif.iconColor.withValues(alpha: 0.5),
                                width: notif.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: notif.iconColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        notif.icon,
                                        color: notif.iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    if (!notif.isRead)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: notif.iconColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.surfaceDark,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: notif.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppDateUtils.formatRelativeTime(
                                              notif.timestamp,
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        notif.message,
                                        style: TextStyle(
                                          color: notif.isRead
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: notif.iconColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              notif.categoryLabel.toUpperCase(),
                                              style: TextStyle(
                                                color: notif.iconColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            notif.isRead
                                                ? 'Tap to view'
                                                : 'Tap to mark read',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = label);
      },
      selectedColor: AppColors.ambulanceTeal,
      backgroundColor: AppColors.cardDark,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.ambulanceTeal : AppColors.borderDark,
      ),
    );
  }
}
