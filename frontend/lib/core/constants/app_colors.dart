import 'package:flutter/material.dart';

/// Design tokens and curated color palette for A2I Ambulance Driver (Daylight Theme)
class AppColors {
  // Daylight Primary Brand Colors
  static const Color primaryDark = Color(0xFFF8FAFC);  // Crisp daylight background (Slate 50)
  static const Color surfaceDark = Color(0xFFFFFFFF);  // Clean white card surfaces
  static const Color cardDark = Color(0xFFF1F5F9);     // Elevated surface (Slate 100)
  static const Color borderDark = Color(0xFFE2E8F0);   // Crisp subtle borders (Slate 200)

  // Emergency Accents (High-visibility for daylight driving)
  static const Color emergencyRed = Color(0xFFDC2626);     // Emergency Crimson (Red 600)
  static const Color emergencyRedGlow = Color(0x22DC2626);
  static const Color ambulanceTeal = Color(0xFF0284C7);    // Medical Response Blue (Sky 600)
  static const Color statusGreen = Color(0xFF16A34A);      // Operational Green (Green 600)
  static const Color statusGreenGlow = Color(0x2216A34A);
  static const Color alertOrange = Color(0xFFEA580C);      // High-priority Alert (Orange 600)
  static const Color warningYellow = Color(0xFFCA8A04);    // Moderate Alert

  // Neutral tones for maximum daytime readability
  static const Color textPrimary = Color(0xFF0F172A);      // Deep Slate 900
  static const Color textSecondary = Color(0xFF475569);    // Slate 600
  static const Color textMuted = Color(0xFF94A3B8);        // Slate 400
  static const Color divider = Color(0xFFE2E8F0);          // Slate 200

  // Status Colors for Verification
  static const Color verified = Color(0xFF16A34A);
  static const Color pending = Color(0xFFEA580C);
  static const Color rejected = Color(0xFFDC2626);
  static const Color suspended = Color(0xFF64748B);

  // Triage Emergency Levels
  static const Color triageCritical = Color(0xFFDC2626);
  static const Color triageUrgent = Color(0xFFEA580C);
  static const Color triageStandard = Color(0xFF0284C7);
  static const Color triageNonUrgent = Color(0xFF16A34A);
}
