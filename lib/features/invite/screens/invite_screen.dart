import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/event_suggestions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_handler.dart';
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

  List<WishList> _shareableLists = []; // Lists with visibility = 'friends'
  Set<String> _selectedListUids = {}; // Selected list UIDs
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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

      // Filter to only 'friends' visibility lists (shareable)
      final shareableLists =
          lists.where((l) => l.visibility == ListVisibility.friends).toList();

      // Sort alphabetically by title
      shareableLists.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

      if (mounted) {
        setState(() {
          _shareableLists = shareableLists;
          // Select all lists by default
          _selectedListUids = shareableLists.map((l) => l.uid).toSet();
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
    if (_selectedListUids.isEmpty) {
      AppNotification.error(
        context,
        'Please select at least one list to share',
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final invite = await _inviteService.createInviteLink(
        listUids: _selectedListUids.toList(),
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

    final listCount = _selectedListUids.length;
    String message;
    if (listCount == 1) {
      final listTitle =
          _shareableLists
              .firstWhere(
                (l) => l.uid == _selectedListUids.first,
                orElse: () => _shareableLists.first,
              )
              .title;
      message = 'Join my list "$listTitle" on ShizList!';
    } else {
      message = 'Join my $listCount lists on ShizList!';
    }

    try {
      // Get the button position for iPad share popover
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await Share.share(
        '$message\n\n${_currentInvite!.inviteUrl}',
        subject: 'ShizList Invite',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        AppNotification.error(
          context,
          ErrorHandler.getUserMessage(e, fallbackMessage: 'Failed to share'),
        );
      }
    }
  }

  void _toggleList(String uid) {
    setState(() {
      if (_selectedListUids.contains(uid)) {
        _selectedListUids.remove(uid);
      } else {
        _selectedListUids.add(uid);
      }
      // Reset invite when selection changes
      _currentInvite = null;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedListUids = _shareableLists.map((l) => l.uid).toSet();
      _currentInvite = null;
    });
  }

  void _selectNone() {
    setState(() {
      _selectedListUids.clear();
      _currentInvite = null;
    });
  }

  /// Get icon for a list based on its title
  PhosphorIconData _getIconForList(String title) {
    final lowerTitle = title.toLowerCase();

    // Find matching event suggestion
    for (final suggestion in EventSuggestions.all) {
      if (suggestion.name.toLowerCase() == lowerTitle ||
          suggestion.keywords.any(
            (k) => lowerTitle.contains(k.toLowerCase()),
          )) {
        return _getIconForCategory(suggestion.category);
      }
    }

    // Default icon
    return PhosphorIcons.usersThree();
  }

  PhosphorIconData _getIconForCategory(EventCategory category) {
    switch (category) {
      case EventCategory.birthday:
        return PhosphorIcons.cake();
      case EventCategory.wedding:
        return PhosphorIcons.heart();
      case EventCategory.heart:
        return PhosphorIcons.heart();
      case EventCategory.diamond:
        return PhosphorIcons.diamond();
      case EventCategory.gift:
        return PhosphorIcons.gift();
      case EventCategory.star:
        return PhosphorIcons.star();
      case EventCategory.baby:
        return PhosphorIcons.baby();
      case EventCategory.graduation:
        return PhosphorIcons.graduationCap();
      case EventCategory.house:
        return PhosphorIcons.house();
      case EventCategory.trophy:
        return PhosphorIcons.trophy();
      case EventCategory.travel:
        return PhosphorIcons.airplane();
      case EventCategory.car:
        return PhosphorIcons.car();
      case EventCategory.camping:
        return PhosphorIcons.tent();
      case EventCategory.party:
        return PhosphorIcons.confetti();
      case EventCategory.users:
        return PhosphorIcons.usersThree();
      case EventCategory.flower:
        return PhosphorIcons.flower();
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
            child:
                _shareableLists.isEmpty
                    ? _buildNoListsMessage()
                    : _currentInvite != null
                    ? _buildInviteGeneratedView()
                    : _buildListSelectionView(),
          ),
        ),

        // Slide-in notification toast
        if (_toastNotification != null) _buildNotificationToast(),
      ],
    );
  }

  Widget _buildListSelectionView() {
    // Calculate max height for list - show ~3.5 items to hint scrollability
    const double itemHeight = 56.0;
    final double maxListHeight =
        _shareableLists.length > 3
            ? itemHeight * 3.5
            : itemHeight * _shareableLists.length;

    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with share illustration
                Center(
                  child: Image.asset(
                    'assets/images/share.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select lists to share',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which lists your friend(s) will be added to',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Select All / None buttons - bigger and more prominent
                if (_shareableLists.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              _selectedListUids.length == _shareableLists.length
                                  ? null
                                  : _selectAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Select All',
                            style: AppTypography.titleSmall.copyWith(
                              color:
                                  _selectedListUids.length ==
                                          _shareableLists.length
                                      ? AppColors.textHint
                                      : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed:
                              _selectedListUids.isEmpty ? null : _selectNone,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Select none',
                            style: AppTypography.titleSmall.copyWith(
                              color:
                                  _selectedListUids.isEmpty
                                      ? AppColors.textHint
                                      : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // List checklist with constrained height for scrolling
                Container(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics:
                          _shareableLists.length > 3
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                      itemCount: _shareableLists.length,
                      separatorBuilder:
                          (context, index) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.divider,
                          ),
                      itemBuilder: (context, index) {
                        final list = _shareableLists[index];
                        final isSelected = _selectedListUids.contains(list.uid);

                        return InkWell(
                          onTap: () => _toggleList(list.uid),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textHint,
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      isSelected
                                          ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 14),
                                // List icon
                                PhosphorIcon(
                                  _getIconForList(list.title),
                                  size: 22,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                // List title
                                Expanded(
                                  child: Text(
                                    list.title,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Fixed bottom button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: AppButton.primary(
            label:
                _selectedListUids.isEmpty
                    ? 'Select lists to share'
                    : 'Generate invite link',
            icon: PhosphorIcons.link(),
            onPressed:
                _isGenerating || _selectedListUids.isEmpty
                    ? null
                    : _generateInviteLink,
            isLoading: _isGenerating,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteGeneratedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildInviteCard(),
    );
  }

  Widget _buildNoListsMessage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/share.png',
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Text(
            'No shareable lists',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Create a list with "Friends" visibility to share it with others.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Private lists cannot be shared.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textHint,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    final selectedLists =
        _shareableLists
            .where((l) => _selectedListUids.contains(l.uid))
            .toList();

    return Container(
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
                  builder:
                      (buttonContext) => SizedBox(
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

          const SizedBox(height: 8),

          // Show selected lists
          Text(
            selectedLists.length == 1
                ? 'Sharing: ${selectedLists.first.title}'
                : 'Sharing ${selectedLists.length} lists',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // New invite button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentInvite = null;
              });
            },
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              'Change selection',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToast() {
    return AnimatedPositioned(
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
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
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
    );
  }
}
