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
import '../../../widgets/app_bottom_sheet.dart';
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
  Map<String, List<String>> _friendSharedListNames = {};
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

      // For each friend, get the lists they can see
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

      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _friendSharedListNames = friendListNames;
          _isLoading = false;
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
    final subtitleText =
        sharedListNames.isEmpty
            ? 'Can\'t see any lists'
            : sharedListNames.join(', ');

    return ListTile(
      onTap: () => _showFriendListAccessSheet(friend),
      leading: _buildAvatar(friend),
      title: Text(
        friend.displayName,
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        subtitleText,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PhosphorIcon(
        PhosphorIcons.caretRight(),
        color: AppColors.primary,
        size: 24,
      ),
    );
  }

  void _showFriendListAccessSheet(Friend friend) async {
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
            selectedFriendIds: [friend.friendUserId],
            listShareService: _listShareService,
            friendName: friend.displayName,
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
                          ? 'Can\'t see any lists'
                          : _friendSharedListNames[friend.friendUserId]!.join(
                            ', ',
                          ),
                      style: AppTypography.bodyMedium.copyWith(
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
  final List<String> selectedFriendIds;
  final ListShareService listShareService;
  final VoidCallback onComplete;
  final String? friendName;

  const _ManageListsSheet({
    required this.lists,
    required this.selectedFriendIds,
    required this.listShareService,
    required this.onComplete,
    this.friendName,
  });

  @override
  State<_ManageListsSheet> createState() => _ManageListsSheetState();
}

class _ManageListsSheetState extends State<_ManageListsSheet> {
  final Map<String, bool> _listShareStatus = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentShares();
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
    final friendCount = widget.selectedFriendIds.length;
    final description =
        widget.friendName != null
            ? 'Select which lists ${widget.friendName} can see:'
            : 'Select which lists ${friendCount == 1 ? "this friend" : "these friends"} can see:';

    return AppBottomSheet(
      title: 'List access',
      confirmText: 'Save',
      onCancel: () => Navigator.pop(context),
      onConfirm: _isSaving || widget.lists.isEmpty ? null : _saveChanges,
      isLoading: _isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Lists
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.lists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'You don\'t have any lists yet.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            )
          else
            ...widget.lists.map((list) {
              final isShared = _listShareStatus[list.uid] ?? false;
              return _buildListTile(list, isShared);
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildListTile(WishList list, bool isShared) {
    return InkWell(
      onTap: () {
        setState(() {
          _listShareStatus[list.uid] = !isShared;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            // List icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  list.title.isNotEmpty ? list.title[0].toUpperCase() : '?',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // List info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.title, style: AppTypography.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${list.itemCount} items',
                    style: AppTypography.bodySmall.copyWith(
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
}
