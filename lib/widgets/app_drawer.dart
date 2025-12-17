import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/constants/app_constants.dart';
import '../routing/app_router.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// App side drawer with profile, settings, and logout
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _authService = AuthService();

  String get _userName {
    final user = SupabaseService.currentUser;
    if (user == null) return 'Guest';
    return user.userMetadata?['display_name'] as String? ??
        user.email?.split('@').first ??
        'User';
  }

  String get _userEmail {
    return SupabaseService.currentUser?.email ?? '';
  }

  String get _userInitials {
    final name = _userName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header with user info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.surface,
                    child: Text(
                      _userInitials,
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User name
                  Text(
                    _userName,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  if (_userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      _userEmail,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to profile
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to settings
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to help
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.logout,
                    title: 'Log Out',
                    textColor: AppColors.error,
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),

            // App version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
                style: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationLegalese: '© 2024 ShizList. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        Text(
          AppConstants.appTagline,
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Close the drawer first
    Navigator.pop(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          context.go(AppRoutes.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log out: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(color: color),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
