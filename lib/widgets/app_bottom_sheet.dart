import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Reusable bottom sheet component for consistent modal styling throughout the app
class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final String? cancelText;
  final String? confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.cancelText,
    this.confirmText,
    this.onCancel,
    this.onConfirm,
    this.isLoading = false,
  });

  /// Shows the bottom sheet with standard configuration
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String? cancelText,
    String? confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
    bool isLoading = false,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => AppBottomSheet(
        title: title,
        cancelText: cancelText,
        confirmText: confirmText,
        onCancel: onCancel ?? () => Navigator.pop(context),
        onConfirm: onConfirm,
        isLoading: isLoading,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with black background
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                // Cancel button
                if (cancelText != null)
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      cancelText!,
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 60),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Confirm button
                if (confirmText != null)
                  TextButton(
                    onPressed: isLoading ? null : onConfirm,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            confirmText!,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  )
                else
                  const SizedBox(width: 60),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
