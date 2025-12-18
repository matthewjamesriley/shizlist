import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Custom top notification banner
class AppNotification {
  AppNotification._();

  /// Shows a notification banner from the top of the screen
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
    PhosphorIconData? icon,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => _NotificationBanner(
            message: message,
            backgroundColor:
                backgroundColor ?? Colors.black.withValues(alpha: 0.9),
            textColor: textColor ?? Colors.white,
            icon: icon,
            onDismiss: () => overlayEntry.remove(),
            duration: duration,
          ),
    );

    overlay.insert(overlayEntry);
  }

  /// Shows a success notification
  static void success(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: Colors.black,
      icon: PhosphorIcons.checkCircle(),
    );
  }

  /// Shows an error notification
  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: AppColors.error,
      icon: PhosphorIcons.warningCircle(),
    );
  }
}

class _NotificationBanner extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final PhosphorIconData? icon;
  final VoidCallback onDismiss;
  final Duration duration;

  const _NotificationBanner({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismiss,
    required this.duration,
    this.icon,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            bottom: false,
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: _dismiss,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < 0) {
                    _dismiss();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade700, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        PhosphorIcon(
                          widget.icon!,
                          color: widget.textColor,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.message,
                          style: AppTypography.titleMedium.copyWith(
                            color: widget.textColor,
                            fontSize: 18,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
