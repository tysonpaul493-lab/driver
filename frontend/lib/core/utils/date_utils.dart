import 'package:intl/intl.dart';

/// Date and time formatting helpers with guaranteed device-local conversion
class AppDateUtils {
  static String formatTime(DateTime dateTime, {bool includeSeconds = false}) {
    final local = dateTime.toLocal();
    final pattern = includeSeconds ? 'hh:mm:ss a' : 'hh:mm a';
    return DateFormat(pattern).format(local);
  }

  static String formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateFormat('MMM dd, yyyy').format(local);
  }

  static String formatDateTime(DateTime dateTime, {bool includeSeconds = false}) {
    final local = dateTime.toLocal();
    final pattern = includeSeconds ? 'MMM dd, yyyy • hh:mm:ss a' : 'MMM dd, yyyy • hh:mm a';
    return DateFormat(pattern).format(local);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} min';
  }

  static String formatRelativeTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inSeconds.abs() < 60) {
      return 'Just now';
    } else if (difference.inMinutes.abs() < 60) {
      return '${difference.inMinutes.abs()}m ago';
    } else if (difference.inHours.abs() < 24) {
      return '${difference.inHours.abs()}h ago';
    } else if (difference.inDays.abs() == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, hh:mm a').format(local);
    }
  }
}
