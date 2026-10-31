import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum NotificationType {
  newBooking,
  bookingExpired,
  acceptedByOther,
  userCancelled,
  destinationChanged,
  dispatcherInstruction,
  reassignment,
  supportMessage,
  systemAlert,
}

class AppNotificationModel {
  final int id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  IconData get icon {
    switch (type) {
      case NotificationType.newBooking:
        return Icons.emergency_rounded;
      case NotificationType.bookingExpired:
        return Icons.timer_off_outlined;
      case NotificationType.acceptedByOther:
        return Icons.person_remove_outlined;
      case NotificationType.userCancelled:
        return Icons.cancel_outlined;
      case NotificationType.destinationChanged:
        return Icons.edit_location_alt_rounded;
      case NotificationType.dispatcherInstruction:
        return Icons.campaign_rounded;
      case NotificationType.reassignment:
        return Icons.swap_horiz_rounded;
      case NotificationType.supportMessage:
        return Icons.support_agent_rounded;
      case NotificationType.systemAlert:
        return Icons.phonelink_setup_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.newBooking:
        return AppColors.emergencyRed;
      case NotificationType.acceptedByOther:
      case NotificationType.userCancelled:
      case NotificationType.bookingExpired:
        return AppColors.alertOrange;
      case NotificationType.destinationChanged:
      case NotificationType.dispatcherInstruction:
        return AppColors.ambulanceTeal;
      case NotificationType.reassignment:
      case NotificationType.supportMessage:
        return AppColors.statusGreen;
      case NotificationType.systemAlert:
        return const Color(0xFF64B5F6);
    }
  }

  String get categoryLabel {
    switch (type) {
      case NotificationType.newBooking:
      case NotificationType.acceptedByOther:
      case NotificationType.userCancelled:
      case NotificationType.bookingExpired:
        return 'Dispatch';
      case NotificationType.destinationChanged:
      case NotificationType.dispatcherInstruction:
        return 'Hospital & Route';
      case NotificationType.supportMessage:
        return 'Support';
      case NotificationType.systemAlert:
        return 'System';
      case NotificationType.reassignment:
        return 'Operations';
    }
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    NotificationType nType = NotificationType.dispatcherInstruction;
    final typeStr = json['type']?.toString().toLowerCase() ?? '';
    if (typeStr.contains('system')) {
      nType = NotificationType.systemAlert;
    } else if (typeStr.contains('booking') || typeStr.contains('request')) {
      nType = NotificationType.newBooking;
    } else if (typeStr.contains('cancel')) {
      nType = NotificationType.userCancelled;
    } else if (typeStr.contains('other') || typeStr.contains('claimed')) {
      nType = NotificationType.acceptedByOther;
    } else if (typeStr.contains('destination')) {
      nType = NotificationType.destinationChanged;
    } else if (typeStr.contains('support')) {
      nType = NotificationType.supportMessage;
    }

    return AppNotificationModel(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch % 10000,
      title: json['title'] as String? ?? 'Dispatch Notice',
      message: json['message'] as String? ?? 'Operational update from emergency central control.',
      type: nType,
      timestamp: json['created_at'] != null || json['timestamp'] != null
          ? DateTime.tryParse((json['created_at'] ?? json['timestamp']).toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }
}
