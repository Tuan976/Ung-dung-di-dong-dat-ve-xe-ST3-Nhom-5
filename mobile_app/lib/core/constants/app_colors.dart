import 'package:flutter/material.dart';

/// Design System Color Palette — Modern Orange & White
/// TRIPLY Premium Transportation Platform
class AppColors {
  // Brand Primary — Orange
  static const Color primary = Color(0xFFF26A21);
  static const Color primaryDark = Color(0xFFDD5714);
  static const Color primaryLight = Color(0xFFFFF0E7);
  static const Color primaryTint = Color(0xFFFFECE0);

  // Accent Secondary — Deep Navy (Used strictly for high-contrast accents, never large dark cards)
  static const Color secondary = Color(0xFF24344D);
  static const Color secondaryLight = Color(0xFF334A6E);

  // Background & Surfaces
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFFFF9F5);
  static const Color surfaceMuted = Color(0xFFF1F3F7);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF202938);
  static const Color textSecondary = Color(0xFF687386);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE8EBF0);
  static const Color borderLight = Color(0xFFF0F2F6);
  static const Color divider = Color(0xFFEEF1F5);

  // Feedback Colors
  static const Color success = Color(0xFF16A36A);
  static const Color successBg = Color(0xFFE9F8F0);
  static const Color successBorder = Color(0xFFC2ECD5);

  static const Color warning = Color(0xFFE99A22);
  static const Color warningBg = Color(0xFFFFF5E5);
  static const Color warningBorder = Color(0xFFFFE0B2);

  static const Color error = Color(0xFFDC4545);
  static const Color errorBg = Color(0xFFFDECEC);
  static const Color errorBorder = Color(0xFFF8C6C6);

  static const Color info = Color(0xFF2878D0);
  static const Color infoBg = Color(0xFFEAF3FF);
  static const Color infoBorder = Color(0xFFBAD8FB);

  // Seat Selection Colors
  static const Color seatAvailable = Color(0xFFFFFFFF);
  static const Color seatAvailableBorder = Color(0xFFD5DBE5);
  static const Color seatSelected = Color(0xFFF26A21);
  static const Color seatOccupied = Color(0xFFE2E6ED);
  static const Color seatOccupiedIcon = Color(0xFFA0ABBA);
  static const Color seatUnavailable = Color(0xFFEDF0F5);
  static const Color seatVip = Color(0xFFFFF4DE);
  static const Color seatVipBorder = Color(0xFFF59E0B);

  // Vehicle License Plate Color
  static const Color licensePlateYellow = Color(0xFFFACC15);

  // Card Shadow Helper
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF202938).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF202938).withValues(alpha: 0.02),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get activeGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
