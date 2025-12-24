import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/constants/app_constants.dart';
import '../routing/app_router.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'profile_sheet.dart';
import 'app_dialog.dart';

/// App side drawer with profile, settings, and logout
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _authService = AuthService();
  UserProfile? _userProfile;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
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
      // Silently fail - will show icon instead
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}';
        });
      }
    } catch (e) {
      // Fallback to constant
      _appVersion = 'v${AppConstants.appVersion}';
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

  String? get _avatarUrl => _userProfile?.avatarUrl;

  void _openProfile() {
    Navigator.pop(context);
    ProfileSheet.show(context).then((_) {
      // Refresh drawer state after profile update
      _loadProfile();
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: SafeArea(
            child: Column(
              children: [
                // Header with user info - tappable to open profile
                GestureDetector(
                  onTap: _openProfile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
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
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Center(
                                            child: PhosphorIcon(
                                              PhosphorIcons.user(),
                                              size: 28,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                    )
                                    : Center(
                                      child: PhosphorIcon(
                                        PhosphorIcons.user(),
                                        size: 28,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // User name
                        Expanded(
                          child: Text(
                            _userName,
                            style: AppTypography.titleLarge.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Divider(color: Colors.white.withValues(alpha: 0.1)),

                // Menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _DrawerItem(
                        icon: PhosphorIcons.user(),
                        title: 'Profile',
                        onTap: _openProfile,
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.gear(),
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/settings');
                        },
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.question(),
                        title: 'Help & support',
                        onTap: () {
                          Navigator.pop(context);
                          _openUrl('https://shizlist.co/support');
                        },
                      ),
                      _DrawerItem(
                        icon: PhosphorIcons.info(),
                        title: 'About',
                        onTap: () {
                          Navigator.pop(context);
                          _openUrl('https://shizlist.co/about');
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

                // App version (dynamic)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${AppConstants.appName} $_appVersion',
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

  Future<void> _handleLogout(BuildContext context) async {
    // Close the drawer first
    Navigator.pop(context);

    // Show confirmation dialog
    final confirmed = await AppDialog.show(
      context,
      title: 'Log Out',
      content: 'Are you sure you want to log out?',
      cancelText: 'Cancel',
      confirmText: 'Log Out',
      isDestructive: true,
    );

    if (confirmed) {
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
