import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// ShizList Typography System
/// Headline/Display: Lato (Bold 700 / Black 900)
/// Body/UI Text: Source Sans Pro (Regular 400 / Semi-Bold 600)
class AppTypography {
  AppTypography._();

  // Lato - Headlines & Display
  static TextStyle get displayLarge => GoogleFonts.lato(
    fontSize: 57,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
  );

  static TextStyle get displayMedium => GoogleFonts.lato(
    fontSize: 45,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  static TextStyle get displaySmall => GoogleFonts.lato(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineLarge => GoogleFonts.lato(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.lato(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineSmall => GoogleFonts.lato(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.lato(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.lato(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.15,
  );

  static TextStyle get titleSmall => GoogleFonts.lato(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  // Source Sans Pro - Body & UI Text
  static TextStyle get bodyLarge => GoogleFonts.sourceSans3(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.25,
  );

  static TextStyle get bodySmall => GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static TextStyle get labelLarge => GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.sourceSans3(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // Special Styles
  static TextStyle get buttonText => GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.25,
  );

  static TextStyle get priceText => GoogleFonts.lato(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static TextStyle get categoryBadge => GoogleFonts.sourceSans3(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get claimedBadge => GoogleFonts.lato(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: 0.5,
  );

  // Create a complete TextTheme
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
