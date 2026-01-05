import 'package:flutter/material.dart';

/// App Color Palette
/// Customize these colors for your brand
class AppColors {
  AppColors._();

  // ============================================
  // TODO: Customize your brand colors
  // ============================================

  // Primary Accent - Your main brand color
  static const Color primary = Color(0xFF009688);      // Teal
  static const Color primaryLight = Color(0xFF3cb7a3);
  static const Color primaryDark = Color(0xFF00796B);

  // Secondary Accent - Complementary color
  static const Color accent = Color(0xFFec332f);       // Red
  static const Color accentLight = Color.fromARGB(255, 244, 91, 89);
  static const Color accentDark = Color.fromARGB(255, 197, 39, 36);

  // ============================================
  // Standard colors (usually don't need changing)
  // ============================================

  // Background
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Colors
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningDark = Color(0xFFFFA000);

  // Dividers & Borders
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFBDBDBD);

  // Shadows
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // Gradients
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




