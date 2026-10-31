import 'package:flutter/services.dart';

/// Sound and Haptic feedback service for critical emergency ambulance notifications
class AudioAlertService {
  static Future<void> playDispatchAlert() async {
    // Heavy haptic vibration sequence for incoming emergency booking
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
      // System sound click/alert
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static Future<void> playActionConfirmed() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> playErrorAlert() async {
    try {
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
