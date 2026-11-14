import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trip_history_item.dart';

final tripHistoryProvider = FutureProvider<List<TripHistoryItem>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);

  final List<TripHistoryItem> items = [];

  // 1. First load local completed trips persisted in secure storage
  try {
    final localRaw = await storage.getCompletedTrips();
    for (final raw in localRaw) {
      try {
        final item = TripHistoryItem.fromJson(raw);
        if (!items.any((x) => x.bookingReference == item.bookingReference || (x.id != 0 && x.id == item.id))) {
          items.add(item);
        }
      } catch (_) {}
    }
  } catch (_) {}

  // 2. Fetch remote records from Laravel backend if online
  try {
    final response = await dio.get(ApiConstants.tripHistory);
    final list = response['trips'] as List? ?? [];
    for (final e in list) {
      try {
        final item = TripHistoryItem.fromJson(e as Map<String, dynamic>);
        if (!items.any((x) => x.bookingReference == item.bookingReference || (x.id != 0 && x.id == item.id))) {
          items.add(item);
        }
      } catch (_) {}
    }
  } catch (_) {}

  // Sort descending by completion time (most recent first) and guarantee 100% unique dispatches
  final seen = <String>{};
  final deduped = <TripHistoryItem>[];
  for (final item in items) {
    final key = item.bookingReference.isNotEmpty ? item.bookingReference : item.id.toString();
    if (seen.add(key)) {
      deduped.add(item);
    }
  }
  deduped.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return deduped;
});

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open dialer for $phone')),
        );
      }
    }
  }

  void _showCompleteStatusModal(BuildContext context, WidgetRef ref, TripHistoryItem trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.ambulanceTeal, width: 2)),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.bookingReference,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                trip.status,
                                style: const TextStyle(
                                  color: AppColors.statusGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      StatusBadge.triage(trip.emergencyCategory),
                    ],
                  ),
                ),
                const Divider(color: AppColors.divider, height: 16),

                // Scrollable Details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PATIENT DETAILS',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.ambulanceTeal.withValues(alpha: 0.15),
                                    child: const Icon(Icons.person, color: AppColors.ambulanceTeal, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip.patientName,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          trip.patientPhone ?? 'Contact not recorded',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (trip.patientPhone != null)
                                    IconButton(
                                      icon: const Icon(Icons.call, color: AppColors.statusGreen),
                                      onPressed: () => _makePhoneCall(context, trip.patientPhone),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Route Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DISPATCH ROUTE',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.radio_button_checked, color: AppColors.emergencyRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pickup Location', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        Text(trip.pickupAddress, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
                                child: Container(
                                  width: 2,
                                  height: 20,
                                  color: AppColors.borderDark,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.local_hospital_rounded, color: AppColors.statusGreen, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Destination Hospital', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        Text(trip.destinationHospital, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Metrics & Vehicle
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TOTAL DISTANCE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${trip.distanceKm} km', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TRIP DURATION', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${trip.durationMinutes} mins', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('AMBULANCE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      trip.ambulancePlate ?? 'ALS Unit',
                                      style: const TextStyle(color: AppColors.ambulanceTeal, fontSize: 14, fontWeight: FontWeight.w800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Handover Notes Card
                        if (trip.handoverNotes != null && trip.handoverNotes!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x1800E5FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.ambulanceTeal.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.notes_rounded, color: AppColors.ambulanceTeal, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'CLINICAL HANDOVER NOTES',
                                      style: TextStyle(
                                        color: AppColors.ambulanceTeal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  trip.handoverNotes!,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Payment Status & Action Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: trip.isPaid ? const Color(0x1806D6A0) : const Color(0x18FFB703),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: trip.isPaid ? AppColors.statusGreen : AppColors.alertOrange,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        trip.isPaid ? Icons.paid_rounded : Icons.pending_actions_rounded,
                                        color: trip.isPaid ? AppColors.statusGreen : AppColors.alertOrange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        trip.isPaid ? 'PAYMENT COMPLETED' : 'PAYMENT PENDING / UNPAID',
                                        style: TextStyle(
                                          color: trip.isPaid ? AppColors.statusGreen : AppColors.alertOrange,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (trip.isPaid)
                                    Text(
                                      '₹${trip.earnings.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.statusGreen,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                trip.isPaid
                                    ? 'Payment Method: ${trip.paymentMethod ?? "Digital / Cash"}'
                                    : 'User has not completed payment for this emergency dispatch. The rupee earnings will appear in the trip bar once paid.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                              ),

                              if (!trip.isPaid) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final updated = trip.copyWith(
                                        isPaid: true,
                                        paymentStatus: 'Paid',
                                        paymentMethod: 'Cash / Collected by Pilot',
                                      );
                                      final storage = ref.read(storageServiceProvider);
                                      await storage.updateCompletedTrip(updated.toJson());
                                      ref.invalidate(tripHistoryProvider);

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppColors.surfaceDark,
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Payment recorded! ₹${updated.earnings.toStringAsFixed(0)} is now visible in the trip bar.',
                                                    style: const TextStyle(
                                                      color: AppColors.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.ambulanceTeal,
                                      foregroundColor: Colors.white,
                                      enableFeedback: true,
                                      splashFactory: InkRipple.splashFactory,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: Text('Mark as Paid (Collect ₹${trip.earnings.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Timestamp
                        Center(
                          child: Text(
                            'Dispatch Completed: ${AppDateUtils.formatDateTime(trip.completedAt)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tripHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Dispatches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Trips',
            onPressed: () => ref.refresh(tripHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.ambulanceTeal),
        ),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.emergencyRed)),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_toggle_off_rounded, size: 54, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No completed trips recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          // Earnings only sum trips where user has actually paid!
          final paidTrips = trips.where((t) => t.isPaid).toList();
          final totalEarnings = paidTrips.fold<double>(0.0, (acc, item) => acc + item.earnings);
          final totalDistance = trips.fold<double>(0.0, (acc, item) => acc + item.distanceKm);
          final unpaidCount = trips.length - paidTrips.length;

          return Column(
            children: [
              // Summary Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('TOTAL DISPATCHES', '${trips.length}'),
                    Container(height: 30, width: 1, color: AppColors.divider),
                    _buildStatItem('TOTAL DISTANCE', '${totalDistance.toStringAsFixed(1)} km'),
                    Container(height: 30, width: 1, color: AppColors.divider),
                    _buildStatItem(
                      'TOTAL COLLECTED',
                      '₹${totalEarnings.toStringAsFixed(0)}',
                      subText: unpaidCount > 0 ? '$unpaidCount Unpaid' : null,
                    ),
                  ],
                ),
              ),

              // Trip list with tap for complete status and payment-dependent rupees
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppColors.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: trip.isPaid ? AppColors.borderDark : AppColors.alertOrange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        enableFeedback: true,
                        splashColor: AppColors.ambulanceTeal.withValues(alpha: 0.15),
                        highlightColor: AppColors.ambulanceTeal.withValues(alpha: 0.08),
                        onTap: () => _showCompleteStatusModal(context, ref, trip),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        trip.bookingReference,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  StatusBadge.triage(trip.emergencyCategory),
                                ],
                              ),
                              const Divider(height: 18, color: AppColors.divider),
                              _buildRouteRow(Icons.radio_button_checked, AppColors.emergencyRed, 'Pickup', trip.pickupAddress),
                              const SizedBox(height: 6),
                              _buildRouteRow(Icons.location_on, AppColors.statusGreen, 'Hospital', trip.destinationHospital),
                              const Divider(height: 18, color: AppColors.divider),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${trip.distanceKm} km • ${trip.durationMinutes} mins',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  // RUPEES BAR: Only show rupees when user paid; if unpaid, remove rupees from bar!
                                  if (trip.isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.statusGreen.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check, color: AppColors.statusGreen, size: 13),
                                          const SizedBox(width: 3),
                                          Text(
                                            '₹${trip.earnings.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppColors.statusGreen,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.alertOrange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.alertOrange.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.pending_outlined, color: AppColors.alertOrange, size: 13),
                                          SizedBox(width: 4),
                                          Text(
                                            'Unpaid',
                                            style: TextStyle(
                                              color: AppColors.alertOrange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppDateUtils.formatDateTime(trip.completedAt),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  Row(
                                    children: const [
                                      Text(
                                        'View Complete Status',
                                        style: TextStyle(color: AppColors.ambulanceTeal, fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded, color: AppColors.ambulanceTeal, size: 16),
                                    ],
                                  ),
                                ],
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
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {String? subText}) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        if (subText != null) ...[
          const SizedBox(height: 2),
          Text(subText, style: const TextStyle(color: AppColors.alertOrange, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _buildRouteRow(IconData icon, Color color, String type, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(height: 1.35),
                children: [
                  TextSpan(text: '$type: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  TextSpan(text: text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
