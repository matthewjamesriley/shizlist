import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routing/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_settings_service.dart';
import '../../../widgets/app_dialog.dart';

/// Home screen - shown after login
/// Replace this with your app's main screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final UserSettingsService _userSettings = UserSettingsService();

  Future<void> _handleLogout() async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Log out',
      content: 'Are you sure you want to log out?',
      confirmText: 'Log out',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      await _authService.signOut();
      context.go(AppRoutes.signup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _userSettings.userProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.signOut(), size: 24),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome message
              PhosphorIcon(
                PhosphorIcons.checkCircle(),
                size: 80,
                color: AppColors.success,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome${profile != null ? ", ${profile.nameOrEmail}" : ""}!',
                style: GoogleFonts.lato(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your app is ready to build!',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Instructions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next steps:',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStep('1', 'Update supabase_config.dart with your credentials'),
                    _buildStep('2', 'Create your database tables in Supabase'),
                    _buildStep('3', 'Add your custom models and services'),
                    _buildStep('4', 'Build your screens and features'),
                    _buildStep('5', 'Customize colors and fonts in the theme'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}




