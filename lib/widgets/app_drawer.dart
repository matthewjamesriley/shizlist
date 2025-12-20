import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/constants/app_constants.dart';
import '../routing/app_router.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'profile_sheet.dart';

/// App side drawer with profile, settings, and logout
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _authService = AuthService();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      // Silently fail - will show initials instead
    }
  }

  String get _userName {
    if (_userProfile?.displayName != null) {
      return _userProfile!.displayName!;
    }
    final user = SupabaseService.currentUser;
    if (user == null) return 'Guest';
    return user.userMetadata?['display_name'] as String? ??
        user.email?.split('@').first ??
        'User';
  }

  String get _userEmail {
    return _userProfile?.email ?? SupabaseService.currentUser?.email ?? '';
  }

  String? get _avatarUrl => _userProfile?.avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: SafeArea(
            child: Column(
              children: [
                // Header with user info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              _avatarUrl != null
                                  ? Image.network(
                                    _avatarUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Center(
                                          child: PhosphorIcon(
                                            PhosphorIcons.user(),
                                            size: 36,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                  )
                                  : Center(
                                    child: PhosphorIcon(
                                      PhosphorIcons.user(),
                                      size: 36,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // User name
                      Text(
                        _userName,
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (_userEmail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        // Email
                        Text(
                          _userEmail,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white70,
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
                        icon: PhosphorIcons.user(),
                        title: 'Profile',
                        onTap: () {
                          Navigator.pop(context);
                          ProfileSheet.show(context).then((_) {
                            // Refresh drawer state after profile update
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.gear(),
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: Navigate to settings
                        },
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.question(),
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: Navigate to help
                        },
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.info(),
                        title: 'About',
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog(context);
                        },
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.1)),
                      _DrawerItem(
                        icon: PhosphorIcons.signOut(),
                        title: 'Log Out',
                        textColor: AppColors.errorLight,
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
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        Text(AppConstants.appTagline, style: AppTypography.bodyMedium),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Close the drawer first
    Navigator.pop(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
  final PhosphorIconData icon;
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
    final color = textColor ?? Colors.white;

    return ListTile(
      leading: PhosphorIcon(icon, color: color, size: 24),
      title: Text(title, style: AppTypography.bodyLarge.copyWith(color: color)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
