import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Shared header component for bottom sheets
/// Ensures consistent styling across all modals in the app
class BottomSheetHeader extends StatelessWidget {
  final String title;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;

  const BottomSheetHeader({
    super.key,
    required this.title,
    this.cancelText = 'Cancel',
    required this.confirmText,
    required this.onCancel,
    this.onConfirm,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Title - centered
          Text(
            title,
            style: AppTypography.titleLarge.copyWith(color: Colors.white),
          ),

          // Buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cancel button
              GestureDetector(
                onTap: onCancel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    cancelText,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Confirm button - pill style
              GestureDetector(
                onTap: isLoading ? null : onConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          confirmText,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

