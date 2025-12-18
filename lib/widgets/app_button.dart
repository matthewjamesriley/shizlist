import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';

/// Button variants similar to Bootstrap
enum ButtonVariant {
  primary,
  secondary,
  success,
  danger,
  warning,
  outline,
  outlinePrimary,
  ghost,
}

/// Button sizes
enum ButtonSize { small, medium, large }

/// Reusable button component with Bootstrap-like variants
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  // Convenience constructors
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.secondary;

  const AppButton.success({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.success;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.danger;

  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.outline;

  const AppButton.outlinePrimary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.outlinePrimary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = ButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: _foregroundColor,
          disabledBackgroundColor: _backgroundColor.withValues(alpha: 0.6),
          disabledForegroundColor: _foregroundColor.withValues(alpha: 0.6),
          elevation: 0,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            side:
                _hasBorder
                    ? BorderSide(color: _borderColor, width: 1.5)
                    : BorderSide.none,
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: _iconSize,
                  width: _iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _foregroundColor,
                  ),
                )
                : Row(
                  mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      PhosphorIcon(
                        icon!,
                        size: _iconSize,
                        color: _foregroundColor,
                      ),
                      SizedBox(width: _iconSpacing),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.lato(
                        fontSize: _fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.0,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      SizedBox(width: _iconSpacing),
                      PhosphorIcon(
                        trailingIcon!,
                        size: _iconSize,
                        color: _foregroundColor,
                      ),
                    ],
                  ],
                ),
      ),
    );
  }

  // Size configurations
  double get _height {
    switch (size) {
      case ButtonSize.small:
        return 40;
      case ButtonSize.medium:
        return 52;
      case ButtonSize.large:
        return 60;
    }
  }

  double get _fontSize {
    switch (size) {
      case ButtonSize.small:
        return 18;
      case ButtonSize.medium:
        return 22;
      case ButtonSize.large:
        return 26;
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.small:
        return 18;
      case ButtonSize.medium:
        return 22;
      case ButtonSize.large:
        return 26;
    }
  }

  double get _iconSpacing {
    switch (size) {
      case ButtonSize.small:
        return 6;
      case ButtonSize.medium:
        return 10;
      case ButtonSize.large:
        return 12;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  double get _borderRadius {
    switch (size) {
      case ButtonSize.small:
        return 20;
      case ButtonSize.medium:
        return 26;
      case ButtonSize.large:
        return 30;
    }
  }

  // Variant configurations
  Color get _backgroundColor {
    switch (variant) {
      case ButtonVariant.primary:
        return AppColors.primary;
      case ButtonVariant.secondary:
        return AppColors.textPrimary;
      case ButtonVariant.success:
        return AppColors.success;
      case ButtonVariant.danger:
        return AppColors.error;
      case ButtonVariant.warning:
        return AppColors.warning;
      case ButtonVariant.outline:
      case ButtonVariant.outlinePrimary:
      case ButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.secondary:
      case ButtonVariant.success:
      case ButtonVariant.danger:
        return Colors.white;
      case ButtonVariant.warning:
        return AppColors.textPrimary;
      case ButtonVariant.outline:
        return AppColors.textPrimary;
      case ButtonVariant.outlinePrimary:
        return AppColors.primary;
      case ButtonVariant.ghost:
        return AppColors.textSecondary;
    }
  }

  bool get _hasBorder {
    switch (variant) {
      case ButtonVariant.outline:
      case ButtonVariant.outlinePrimary:
        return true;
      default:
        return false;
    }
  }

  Color get _borderColor {
    switch (variant) {
      case ButtonVariant.outline:
        return AppColors.border;
      case ButtonVariant.outlinePrimary:
        return AppColors.primary;
      default:
        return Colors.transparent;
    }
  }
}
