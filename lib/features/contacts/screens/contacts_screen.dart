import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/friend.dart';
import '../../../models/wish_list.dart';
import '../../../routing/app_router.dart';
import '../../../services/friend_service.dart';
import '../../../services/list_service.dart';
import '../../../services/list_share_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_notification.dart';

/// Friends screen for managing friends and shared list participants
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  final _friendService = FriendService();
  final _listService = ListService();
  final _listShareService = ListShareService();

  List<Friend> _friends = [];
  List<Friend> _filteredFriends = [];
  Map<String, List<String>> _friendSharedListNames =
      {}; // Lists user shared WITH friend
  Map<String, List<WishList>> _friendsListsSharedWithMe =
      {}; // Lists friend shared WITH user
  bool _isLoading = true;
  String? _error;

  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedFriendIds = {};

  // For showing/hiding floating buttons on scroll
  bool _showButtons = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final friends = await _friendService.getFriends();
      final lists = await _listService.getUserLists();

      // Build a map of list uid -> list title
      final listTitleMap = <String, String>{};
      for (final list in lists) {
        listTitleMap[list.uid] = list.title;
      }

      // For each friend, get the lists they can see (user's lists shared with friend)
      final friendListNames = <String, List<String>>{};
      for (final friend in friends) {
        final sharedListUids = await _listShareService.getListsSharedWithUser(
          friend.friendUserId,
        );
        final listNames =
            sharedListUids
                .where((uid) => listTitleMap.containsKey(uid))
                .map((uid) => listTitleMap[uid]!)
                .toList();
        friendListNames[friend.friendUserId] = listNames;
      }

      // Get lists shared WITH the current user (friend's lists)
      // This is optional - don't fail the whole page if it errors
      var friendsListsWithMe = <String, List<WishList>>{};
      try {
        final sharedWithMe = await _listService.getSharedLists();
        debugPrint('Loaded ${sharedWithMe.length} shared lists with me');
        for (final list in sharedWithMe) {
          debugPrint('  - List "${list.title}" owned by ${list.ownerId}');
        }

        // Group shared lists by friend (owner)
        for (final friend in friends) {
          debugPrint(
            'Checking friend ${friend.displayName} (${friend.friendUserId})',
          );
          final listsFromFriend =
              sharedWithMe
                  .where((list) => list.ownerId == friend.friendUserId)
                  .toList();
          debugPrint(
            '  Found ${listsFromFriend.length} lists from this friend',
          );
          if (listsFromFriend.isNotEmpty) {
            friendsListsWithMe[friend.friendUserId] = listsFromFriend;
          }
        }
      } catch (e) {
        debugPrint('Error loading shared lists: $e');
        // Continue without friend's lists - not critical
      }

      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _friendSharedListNames = friendListNames;
          _friendsListsSharedWithMe = friendsListsWithMe;
          _isLoading = false;
          _showButtons = false; // Start hidden for animation
        });
        // Trigger entrance animation
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() => _showButtons = true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load friends';
          _isLoading = false;
        });
      }
    }
  }

  void _filterFriends(String query) {
    if (query.isEmpty) {
      setState(() => _filteredFriends = _friends);
    } else {
      final lowerQuery = query.toLowerCase();
      setState(() {
        _filteredFriends =
            _friends.where((friend) {
              final name = friend.displayName.toLowerCase();
              final email = friend.friendEmail?.toLowerCase() ?? '';
              return name.contains(lowerQuery) || email.contains(lowerQuery);
            }).toList();
      });
    }
  }

  void _toggleFriendSelection(String friendUserId) {
    setState(() {
      if (_selectedFriendIds.contains(friendUserId)) {
        _selectedFriendIds.remove(friendUserId);
      } else {
        _selectedFriendIds.add(friendUserId);
      }
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedFriendIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: PhosphorIcon(PhosphorIcons.x()),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filteredFriends = _friends;
                              });
                            },
                          )
                          : null,
                ),
                onChanged: _filterFriends,
              ),
            ),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),

        // Floating buttons (positioned at bottom) - like list page
        if (_friends.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset:
                  (_showButtons && !_isMultiSelectMode)
                      ? Offset.zero
                      : const Offset(0, 0.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_showButtons && !_isMultiSelectMode) ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showButtons || _isMultiSelectMode,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Multi select button (left)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap:
                                  () => setState(() {
                                    _isMultiSelectMode = true;
                                    _selectedFriendIds.clear();
                                  }),
                              borderRadius: BorderRadius.circular(32),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                child: Text(
                                  'Multi select (${_friends.length} ${_friends.length == 1 ? 'friend' : 'friends'})',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.black,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Invite button (right) - Orange circle
                      Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(),
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        child: InkWell(
                          onTap: _addFriend,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: PhosphorIcon(
                              PhosphorIcons.userPlus(),
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Retry', onPressed: _loadFriends),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadFriends,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final scrollDelta = notification.scrollDelta ?? 0;
                if (scrollDelta > 5 && _showButtons) {
                  setState(() => _showButtons = false);
                } else if (scrollDelta < -5 && !_showButtons) {
                  setState(() => _showButtons = true);
                }
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: _isMultiSelectMode ? 100 : 120),
              itemCount: _filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = _filteredFriends[index];

                if (_isMultiSelectMode) {
                  return _buildSelectableFriendTile(friend, index);
                }
                return _buildFriendTile(friend);
              },
            ),
          ),
        ),
        // Multi-select bar at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: _isMultiSelectMode ? Offset.zero : const Offset(0, 1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMultiSelectMode ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isMultiSelectMode,
                child: _buildMultiSelectBar(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectBar() {
    return Material(
      elevation: 0,
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        child: Row(
          children: [
            // Selected count
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${_selectedFriendIds.length} selected',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            // Manage Lists button
            if (_selectedFriendIds.isNotEmpty)
              IconButton(
                onPressed: _showManageListsSheet,
                icon: PhosphorIcon(PhosphorIcons.list(), color: Colors.white),
                tooltip: 'Manage Lists',
              ),
            // Remove button
            if (_selectedFriendIds.isNotEmpty)
              IconButton(
                onPressed: _removeSelectedFriends,
                icon: PhosphorIcon(
                  PhosphorIcons.userMinus(),
                  color: AppColors.error,
                ),
                tooltip: 'Remove',
              ),
            // Dotted separator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  6,
                  (index) => Container(
                    width: 2,
                    height: 2,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            // Cancel/Close button
            IconButton(
              onPressed: _exitMultiSelectMode,
              icon: PhosphorIcon(
                PhosphorIcons.xCircle(),
                color: Colors.white.withValues(alpha: 0.7),
                size: 28,
              ),
              tooltip: 'Cancel',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.claimedBackground,
                borderRadius: BorderRadius.circular(50),
              ),
              child: PhosphorIcon(
                PhosphorIcons.users(),
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('No friends yet', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add friends and family to easily share your lists with them.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Invite Friend',
              icon: PhosphorIcons.userPlus(),
              onPressed: _addFriend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    final sharedListNames = _friendSharedListNames[friend.friendUserId] ?? [];
    final friendsLists = _friendsListsSharedWithMe[friend.friendUserId] ?? [];

    return InkWell(
      onTap: () => _showFriendListAccessSheet(friend),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAvatar(friend),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                friend.displayName,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Circle button: My lists they can see
            _buildCircleButton(
              icon: PhosphorIcons.star(),
              count: sharedListNames.length,
              isActive: sharedListNames.isNotEmpty,
              tooltip: 'Your lists',
              onTap: () => _showFriendListAccessSheet(friend, initialTab: 0),
            ),
            const SizedBox(width: 10),
            // Circle button: Their lists I can view
            _buildCircleButton(
              icon: PhosphorIcons.list(),
              count: friendsLists.length,
              isActive: friendsLists.isNotEmpty,
              tooltip: 'Their lists',
              onTap: () => _showFriendListAccessSheet(friend, initialTab: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Tooltip(
      message: '$tooltip ($count)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Center(child: PhosphorIcon(icon, size: 18, color: color)),
            ),
            if (count > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFriendListAccessSheet(Friend friend, {int initialTab = 0}) async {
    final lists = await _listService.getUserLists();
    final friendsLists = _friendsListsSharedWithMe[friend.friendUserId] ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder:
          (context) => _ManageListsSheet(
            lists: lists,
            friendsLists: friendsLists,
            selectedFriendIds: [friend.friendUserId],
            listShareService: _listShareService,
            friendName: friend.displayName,
            initialTab: initialTab,
            onComplete: () {
              _loadFriends();
            },
          ),
    );
  }

  Widget _buildSelectableFriendTile(Friend friend, int index) {
    final isSelected = _selectedFriendIds.contains(friend.friendUserId);

    // Calculate position for grouped card style
    final itemCount = _filteredFriends.length;
    BorderRadius borderRadius;
    const radius = Radius.circular(12);

    if (itemCount == 1) {
      borderRadius = BorderRadius.circular(12);
    } else if (index == 0) {
      borderRadius = const BorderRadius.only(topLeft: radius, topRight: radius);
    } else if (index == itemCount - 1) {
      borderRadius = const BorderRadius.only(
        bottomLeft: radius,
        bottomRight: radius,
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => _toggleFriendSelection(friend.friendUserId),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
                child:
                    isSelected
                        ? PhosphorIcon(
                          PhosphorIcons.check(PhosphorIconsStyle.bold),
                          size: 16,
                          color: Colors.white,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              // Avatar
              _buildAvatar(friend),
              const SizedBox(width: 12),
              // Name and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (_friendSharedListNames[friend.friendUserId]?.isEmpty ??
                              true)
                          ? 'Can\'t see any of your lists'
                          : _friendSharedListNames[friend.friendUserId]!.join(
                            ', ',
                          ),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Friend friend) {
    if (friend.friendAvatarUrl != null && friend.friendAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(friend.friendAvatarUrl!),
        backgroundColor: AppColors.claimedBackground,
      );
    }

    final colors = [
      AppColors.categoryEvents,
      AppColors.categoryTrips,
      AppColors.categoryStuff,
      AppColors.categoryCrafted,
      AppColors.categoryMeals,
      AppColors.primary,
    ];
    final colorIndex = friend.id % colors.length;
    final color = colors[colorIndex];

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        friend.initials,
        style: AppTypography.titleMedium.copyWith(color: color),
      ),
    );
  }

  void _addFriend() {
    context.go(AppRoutes.invite);
  }

  void _removeSelectedFriends() async {
    final count = _selectedFriendIds.length;
    final confirmed = await AppDialog.show(
      context,
      title: 'Remove Friends',
      content: 'Remove $count ${count == 1 ? 'friend' : 'friends'}?',
      confirmText: 'Remove',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        for (final friendUserId in _selectedFriendIds) {
          final friend = _friends.firstWhere(
            (f) => f.friendUserId == friendUserId,
          );
          await _friendService.removeFriend(friend.id);
        }
        await _loadFriends();
        _exitMultiSelectMode();
        if (mounted) {
          AppNotification.success(context, 'Removed $count friends');
        }
      } catch (e) {
        if (mounted) {
          AppNotification.error(context, 'Failed to remove friends');
        }
      }
    }
  }

  void _showManageListsSheet() async {
    final lists = await _listService.getUserLists();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder:
          (context) => _ManageListsSheet(
            lists: lists,
            friendsLists: const [],
            selectedFriendIds: _selectedFriendIds.toList(),
            listShareService: _listShareService,
            onComplete: () {
              _exitMultiSelectMode();
              _loadFriends();
            },
          ),
    );
  }
}

/// Sheet for managing which lists are shared with selected friends
class _ManageListsSheet extends StatefulWidget {
  final List<WishList> lists;
  final List<WishList> friendsLists;
  final List<String> selectedFriendIds;
  final ListShareService listShareService;
  final VoidCallback onComplete;
  final String? friendName;
  final int initialTab;

  const _ManageListsSheet({
    required this.lists,
    required this.friendsLists,
    required this.selectedFriendIds,
    required this.listShareService,
    required this.onComplete,
    this.friendName,
    this.initialTab = 0,
  });

  @override
  State<_ManageListsSheet> createState() => _ManageListsSheetState();
}

class _ManageListsSheetState extends State<_ManageListsSheet>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _listShareStatus = {};
  bool _isLoading = true;
  bool _isSaving = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadCurrentShares();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentShares() async {
    if (widget.selectedFriendIds.isEmpty) return;

    final firstFriendId = widget.selectedFriendIds.first;

    for (final list in widget.lists) {
      final isShared = await widget.listShareService.isListSharedWithUser(
        list.uid,
        firstFriendId,
      );
      _listShareStatus[list.uid] = isShared;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      for (final entry in _listShareStatus.entries) {
        final listUid = entry.key;
        final shouldShare = entry.value;

        for (final friendId in widget.selectedFriendIds) {
          if (shouldShare) {
            await widget.listShareService.shareListWithUser(listUid, friendId);
          } else {
            await widget.listShareService.unshareListWithUser(
              listUid,
              friendId,
            );
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(context, 'List access updated');
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error updating list access: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.error(context, 'Failed to update list access');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.friendName?.split(' ').first ?? 'Friend';

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
          // Header with black background (matching add_item_sheet)
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Title - centered
                      Text(
                        'Lists',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      // Buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Text(
                                'Close',
                                style: AppTypography.titleMedium.copyWith(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          // Save button - only show on Your lists tab
                          AnimatedBuilder(
                            animation: _tabController,
                            builder: (context, child) {
                              if (_tabController.index != 0) {
                                return const SizedBox(width: 60);
                              }
                              return GestureDetector(
                                onTap:
                                    _isSaving || widget.lists.isEmpty
                                        ? null
                                        : _saveChanges,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child:
                                      _isSaving
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            'Save',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                          ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                    fontSize: 17,
                  ),
                  tabs: [
                    const Tab(text: 'Your lists'),
                    Tab(text: '$firstName\'s lists'),
                  ],
                ),
              ],
            ),
          ),
          // Tab content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [_buildYourListsTab(), _buildTheirListsTab(firstName)],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildYourListsTab() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.listPlus(),
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'You don\'t have any lists yet',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      shrinkWrap: true,
      itemCount: widget.lists.length,
      itemBuilder: (context, index) {
        final list = widget.lists[index];
        final isShared = _listShareStatus[list.uid] ?? false;
        return _buildShareableListTile(list, isShared);
      },
    );
  }

  Widget _buildTheirListsTab(String firstName) {
    if (widget.friendsLists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.eyeSlash(),
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                '$firstName hasn\'t shared any lists with you',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      shrinkWrap: true,
      itemCount: widget.friendsLists.length,
      itemBuilder: (context, index) {
        final list = widget.friendsLists[index];
        return _buildViewableListTile(list);
      },
    );
  }

  Widget _buildShareableListTile(WishList list, bool isShared) {
    return InkWell(
      onTap: () {
        setState(() {
          _listShareStatus[list.uid] = !isShared;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isShared ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isShared ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child:
                  isShared
                      ? PhosphorIcon(
                        PhosphorIcons.check(PhosphorIconsStyle.bold),
                        size: 16,
                        color: Colors.white,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            // List info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${list.itemCount} items',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewableListTile(WishList list) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.push('/lists/${list.uid}');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // List info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${list.itemCount} items',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            PhosphorIcon(
              PhosphorIcons.arrowRight(),
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
