import 'package:flutter/material.dart';

/// ShizList Color Palette
/// Design System compliant colors for consistent UI
class AppColors {
  AppColors._();

  // Primary Accent - ShizList Teal
  static const Color primary = Color(0xFF009688);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00796B);

  // Background - Clean White
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text/Surface - Deep Charcoal
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Error/Alert - Claim Red
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
  
  // Success
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);

  // Warning
  static const Color warning = Color(0xFFFFC107);
  static const Color warningDark = Color(0xFFFFA000);

  // Dividers & Borders
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFBDBDBD);
  
  // Shadows
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // Category Colors
  static const Color categoryStuff = Color(0xFF5C6BC0);      // Indigo
  static const Color categoryEvents = Color(0xFFEC407A);     // Pink
  static const Color categoryTrips = Color(0xFF26A69A);      // Teal variant
  static const Color categoryHomemade = Color(0xFFFFB74D);   // Orange
  static const Color categoryMeals = Color(0xFF66BB6A);      // Green
  static const Color categoryOther = Color(0xFF78909C);      // Blue Grey

  // Claimed Badge
  static const Color claimed = primary;
  static const Color claimedBackground = Color(0xFFE0F2F1);

  // Gradient for splash/special elements
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, surface],
  );
}


