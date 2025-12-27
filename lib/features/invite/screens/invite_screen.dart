import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_notification.dart';
import '../../../models/invite_link.dart';
import '../../../models/wish_list.dart';
import '../../../services/invite_service.dart';
import '../../../services/list_service.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_notification.dart';
import '../../notifications/screens/notifications_screen.dart';

/// Invite screen for inviting friends to ShizList
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final InviteService _inviteService = InviteService();
  final ListService _listService = ListService();
  final NotificationService _notificationService = NotificationService();

  List<WishList> _lists = [];
  WishList? _selectedList;
  InviteLink? _currentInvite;
  bool _isLoading = true;
  bool _isGenerating = false;

  // Slide-in notification toast
  AppNotificationModel? _toastNotification;
  bool _showToast = false;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = _notificationService.newNotificationStream
        .listen((notification) {
          if (mounted) {
            _showNotificationToast(notification);
          }
        });
  }

  void _showNotificationToast(AppNotificationModel notification) {
    // Play alert sound
    final player = AudioPlayer();
    player.play(AssetSource('sounds/alert.mp3'));
    
    // First add the widget to the tree off-screen
    setState(() {
      _toastNotification = notification;
      _showToast = false;
    });
    
    // Then animate it in after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showToast = true);
      }
    });

    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _toastNotification?.uid == notification.uid) {
        setState(() => _showToast = false);
        // Clear notification after animation completes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _toastNotification?.uid == notification.uid) {
            setState(() => _toastNotification = null);
          }
        });
      }
    });
  }

  void _dismissToast() {
    setState(() => _showToast = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _toastNotification = null);
      }
    });
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _listService.getUserLists();
      // Sort alphabetically by title
      lists.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      if (mounted) {
        setState(() {
          _lists = lists;
          // Select first list by default
          _selectedList = lists.isNotEmpty ? lists.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.error(context, 'Failed to load lists');
      }
    }
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isGenerating = true);
    try {
      final invite = await _inviteService.createInviteLink(
        listId: _selectedList?.id,
      );
      if (mounted) {
        setState(() {
          _currentInvite = invite;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        AppNotification.error(context, 'Failed to generate invite link');
      }
    }
  }

  Future<void> _copyLink() async {
    if (_currentInvite == null) return;
    // Clear clipboard first to avoid iOS bplist bug mixing with share data
    await Clipboard.setData(const ClipboardData(text: ''));
    await Future.delayed(const Duration(milliseconds: 50));
    await Clipboard.setData(ClipboardData(text: _currentInvite!.inviteUrl));
    if (mounted) {
      AppNotification.success(context, 'Link copied to clipboard');
    }
  }

  Future<void> _shareLink(BuildContext context) async {
    if (_currentInvite == null) return;

    String message = 'Join me on ShizList!';
    if (_selectedList != null) {
      message = 'Join my list "${_selectedList!.title}" on ShizList!';
    }

    try {
      // Get the button position for iPad share popover
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.share(
      '$message\n\n${_currentInvite!.inviteUrl}',
      subject: 'ShizList Invite',
        sharePositionOrigin: sharePositionOrigin,
    );
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to share: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const SizedBox(height: 0),

          // List selector (optional)
          Text(
            'Share a list (optional)',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<WishList?>(
                value: _selectedList,
                isExpanded: true,
                hint: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.listBullets(),
                      size: 22,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No list selected (app invite only)',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                items: [
                  // "None" option
                  DropdownMenuItem<WishList?>(
                    value: null,
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.prohibit(),
                          size: 22,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'No list (app invite only)',
                          style: AppTypography.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  // User's lists
                  ..._lists.map((list) {
                    return DropdownMenuItem(
                      value: list,
                      child: Row(
                        children: [
                          PhosphorIcon(
                            list.isPublic
                                ? PhosphorIcons.usersThree()
                                : PhosphorIcons.lock(),
                            size: 22,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              list.title,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (list) {
                  setState(() {
                    _selectedList = list;
                    _currentInvite = null; // Reset invite when list changes
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Generate button
          if (_currentInvite == null) ...[
            AppButton.primary(
              label: 'Generate invite link',
              icon: PhosphorIcons.link(),
              onPressed: _isGenerating ? null : _generateInviteLink,
              isLoading: _isGenerating,
            ),
          ] else ...[
            // Invite link generated - show compact QR view
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  // Share and Copy buttons at top
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _copyLink,
                            icon: PhosphorIcon(PhosphorIcons.copy(), size: 20),
                            label: Text(
                              'Copy',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                                child: Builder(
                                  builder: (buttonContext) => SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                                      onPressed: () => _shareLink(buttonContext),
                            icon: PhosphorIcon(
                              PhosphorIcons.shareFat(),
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Share',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: _currentInvite!.inviteUrl,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Scan to join',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.info(),
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedList != null
                        ? 'Your friend(s) will be added to "${_selectedList!.title}" when they accept the invite.'
                        : 'Your friend(s) will be invited to join ShizList. You can share lists with them later.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
            ),
          ),
        ),

        // Slide-in notification toast
        if (_toastNotification != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: 16,
            right: _showToast ? 12 : -350,
            child: GestureDetector(
              onTap: () {
                _dismissToast();
                _openNotifications();
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 0) {
                  _dismissToast();
                }
              },
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.black.withValues(alpha: 0.3),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.bell(PhosphorIconsStyle.fill),
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _toastNotification!.title,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_toastNotification!.message != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _toastNotification!.message!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PhosphorIcon(
                        PhosphorIcons.caretRight(),
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
