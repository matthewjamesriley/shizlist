import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'bottom_sheet_header.dart';

/// Reusable bottom sheet component for consistent modal styling throughout the app
class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final String cancelText;
  final String confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;

  const AppBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.cancelText = 'Cancel',
    this.confirmText = 'Save',
    this.onCancel,
    this.onConfirm,
    this.isLoading = false,
  });

  /// Shows the bottom sheet with standard configuration
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String cancelText = 'Cancel',
    String confirmText = 'Save',
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
      builder:
          (context) => AppBottomSheet(
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
          // Shared header component
          BottomSheetHeader(
            title: title,
            cancelText: cancelText,
            confirmText: confirmText,
            onCancel: onCancel ?? () => Navigator.pop(context),
            onConfirm: onConfirm,
            isLoading: isLoading,
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
