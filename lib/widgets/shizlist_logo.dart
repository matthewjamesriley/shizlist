import 'package:flutter/material.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';

/// ShizList logo widget with optional tagline
class ShizListLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final bool showTagline;
  final bool centerTagline;

  const ShizListLogo({
    super.key,
    this.height,
    this.width,
    this.showTagline = false,
    this.centerTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerTagline ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/ShizList-Logo.png',
          height: height ?? 80,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image fails to load
            return Container(
              height: height ?? 80,
              width: width ?? 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 48,
                color: AppColors.textOnPrimary,
              ),
            );
          },
        ),
        if (showTagline) ...[
          const SizedBox(height: 12),
          Text(
            AppConstants.appTagline,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: centerTagline ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );
  }
}
