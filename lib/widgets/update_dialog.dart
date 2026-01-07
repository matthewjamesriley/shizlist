import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/version_service.dart';

/// Dialog to prompt user to update the app
class UpdateDialog extends StatelessWidget {
  final String newVersion;
  final VoidCallback? onLater;

  const UpdateDialog({super.key, required this.newVersion, this.onLater});

  /// Show the update dialog
  static Future<void> show(BuildContext context, String newVersion) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => UpdateDialog(
            newVersion: newVersion,
            onLater: () {
              VersionService.skipVersion(newVersion);
              Navigator.of(context).pop();
            },
          ),
    );
  }

  Future<void> _openStore() async {
    final url = Uri.parse(VersionService.getStoreUrl());
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shizzie update graphic
            Transform.translate(
              offset: const Offset(20, 0),
              child: Image.asset(
                'assets/images/Shizzie-Update.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Update Available!',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'A new version ($newVersion) of ShizList is available with improvements and bug fixes.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Update Now button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _openStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Update Now',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Later button
            TextButton(
              onPressed: onLater,
              child: Text(
                'Later',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
