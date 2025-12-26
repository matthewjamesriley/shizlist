import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/friend.dart';
import '../../../models/wish_list.dart';
import '../../../services/friend_service.dart';
import '../../../services/list_service.dart';
import '../../../services/list_share_service.dart';
import '../../../services/lists_notifier.dart';
import '../../../services/page_load_notifier.dart';
import '../../../services/view_mode_notifier.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/list_card.dart';
import '../widgets/create_list_dialog.dart';

/// Main lists screen showing user's wish lists
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen>
    with SingleTickerProviderStateMixin {
  final ListsNotifier _listsNotifier = ListsNotifier();
  final ListService _listService = ListService();
  final ListShareService _listShareService = ListShareService();
  final FriendService _friendService = FriendService();
  final ViewModeNotifier _viewModeNotifier = ViewModeNotifier();

  List<WishList> _lists = [];
  Map<String, int> _listFriendsCount = {};
  bool _isLoading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _listsNotifier.addListener(_onListsChanged);
    _viewModeNotifier.addListener(_onViewModeChanged);

    // Entrance fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _loadLists();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listsNotifier.removeListener(_onListsChanged);
    _viewModeNotifier.removeListener(_onViewModeChanged);
    super.dispose();
  }

  void _onViewModeChanged() {
    setState(() {});
  }

  void _onListsChanged() {
    // Handle new list added
    final newList = _listsNotifier.lastAddedList;
    if (newList != null) {
      setState(() {
        _lists.insert(0, newList);
      });
      _listsNotifier.clearLastAdded();
    }

    // Handle list deleted
    final deletedUid = _listsNotifier.lastDeletedListUid;
    if (deletedUid != null) {
      setState(() {
        _lists.removeWhere((list) => list.uid == deletedUid);
      });
      _listsNotifier.clearLastDeleted();
    }

    // Handle item count changed (silently refresh lists)
    if (_listsNotifier.itemCountChanged) {
      _listsNotifier.clearItemCountChanged();
      _silentRefreshLists();
    }
  }

  /// Refresh lists without showing loading indicator
  Future<void> _silentRefreshLists() async {
    try {
      final lists = await _listService.getUserLists();
      final friendsCount = <String, int>{};
      for (final list in lists) {
        final users = await _listShareService.getUsersForList(list.uid);
        friendsCount[list.uid] = users.length;
      }
      if (mounted) {
        setState(() {
          _lists = lists;
          _listFriendsCount = friendsCount;
        });
      }
    } catch (e) {
      // Silently fail - user can pull to refresh if needed
    }
  }

  Future<void> _loadLists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final lists = await _listService.getUserLists();

      // Show lists immediately
      setState(() {
        _lists = lists;
        _isLoading = false;
      });

      // Notify that page has loaded (for button animation)
      PageLoadNotifier().notifyListsPageLoaded();

      // Load friends count in background
      _loadFriendsCountInBackground(lists);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      // Still notify even on error so buttons appear
      PageLoadNotifier().notifyListsPageLoaded();
    }
  }

  /// Load friends count for each list without blocking UI
  Future<void> _loadFriendsCountInBackground(List<WishList> lists) async {
    final friendsCount = <String, int>{};
    for (final list in lists) {
      try {
        final users = await _listShareService.getUsersForList(list.uid);
        friendsCount[list.uid] = users.length;
      } catch (e) {
        // Silently fail for individual lists
      }
    }
    if (mounted) {
      setState(() {
        _listFriendsCount = friendsCount;
      });
    }
  }

  /// Silently refresh lists without showing loading indicator
  Future<void> _silentRefresh() async {
    try {
      final lists = await _listService.getUserLists();
      final friendsCount = <String, int>{};
      for (final list in lists) {
        final users = await _listShareService.getUsersForList(list.uid);
        friendsCount[list.uid] = users.length;
      }
      if (mounted) {
        setState(() {
          _lists = lists;
          _listFriendsCount = friendsCount;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing lists: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnimation, child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_lists.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshLists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];
          return ListCard(
            list: list,
            onTap: () => _openList(list),
            onVisibilityChanged:
                (isPublic) => _updateListVisibility(list, isPublic),
            friendsCount: _listFriendsCount[list.uid] ?? 0,
            onFriendsTap: () => _showManageFriendsSheet(list),
            isCompact: _viewModeNotifier.isCompactView,
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.warning(),
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text('Something went wrong', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLists,
              icon: PhosphorIcon(PhosphorIcons.arrowClockwise()),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, -50),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/No-Lists.png',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(height: 14),
                  Text('No lists yet', style: AppTypography.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first list and start sharing the stuff you love!',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Arrow pointing to FAB (+) button
        Positioned(bottom: 100, right: 24, child: _AnimatedArrow()),
      ],
    );
  }

  Future<void> _refreshLists() async {
    await _loadLists();
  }

  void _openList(WishList list) async {
    await context.push('/lists/${list.uid}');
    // Silently refresh lists when returning to get updated item counts
    _silentRefresh();
  }

  Future<void> _updateListVisibility(WishList list, bool isPublic) async {
    try {
      final updatedList = await _listService.updateList(
        uid: list.uid,
        visibility: isPublic ? ListVisibility.public : ListVisibility.private,
      );

      setState(() {
        final index = _lists.indexWhere((l) => l.uid == list.uid);
        if (index != -1) {
          _lists[index] = updatedList;
        }
      });

      if (mounted) {
        AppNotification.success(
          context,
          'List is now ${isPublic ? 'public' : 'private'}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to update visibility: $e');
      }
    }
  }

  void _deleteList(WishList list) async {
    // Show confirmation dialog
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete "${list.title}"?',
      content:
          'Are you sure you want to delete this list? This action can be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _listService.deleteList(list.uid);
        setState(() {
          _lists.removeWhere((l) => l.uid == list.uid);
        });
        if (mounted) {
          AppNotification.success(context, 'Deleted "${list.title}"');
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            message: 'Failed to delete list: $e',
            icon: PhosphorIcons.warning(),
            backgroundColor: AppColors.error,
          );
        }
      }
    }
  }

  void _createNewList() async {
    final result = await showDialog<WishList>(
      context: context,
      builder: (context) => const CreateListDialog(),
    );

    if (result != null) {
      setState(() {
        _lists.insert(0, result);
      });

      if (mounted) {
        AppNotification.success(context, 'Created "${result.title}"');
      }
    }
  }

  void _showManageFriendsSheet(WishList list) async {
    final friends = await _friendService.getFriends();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useRootNavigator: true,
      builder:
          (context) => _ManageFriendsSheet(
            list: list,
            friends: friends,
            listShareService: _listShareService,
            onComplete: () {
              _silentRefresh();
            },
          ),
    );
  }
}

/// Sheet for managing which friends have access to a list
class _ManageFriendsSheet extends StatefulWidget {
  final WishList list;
  final List<Friend> friends;
  final ListShareService listShareService;
  final VoidCallback onComplete;

  const _ManageFriendsSheet({
    required this.list,
    required this.friends,
    required this.listShareService,
    required this.onComplete,
  });

  @override
  State<_ManageFriendsSheet> createState() => _ManageFriendsSheetState();
}

class _ManageFriendsSheetState extends State<_ManageFriendsSheet> {
  final _searchController = TextEditingController();
  final Map<String, bool> _friendShareStatus = {};
  List<Friend> _filteredFriends = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.friends;
    _loadCurrentShares();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentShares() async {
    final sharedUsers = await widget.listShareService.getUsersForList(
      widget.list.uid,
    );

    for (final friend in widget.friends) {
      _friendShareStatus[friend.friendUserId] = sharedUsers.contains(
        friend.friendUserId,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterFriends(String query) {
    if (query.isEmpty) {
      setState(() => _filteredFriends = widget.friends);
    } else {
      final lowerQuery = query.toLowerCase();
      setState(() {
        _filteredFriends =
            widget.friends.where((friend) {
              final name = friend.displayName.toLowerCase();
              return name.contains(lowerQuery);
            }).toList();
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      for (final entry in _friendShareStatus.entries) {
        final friendId = entry.key;
        final shouldShare = entry.value;

        if (shouldShare) {
          await widget.listShareService.shareListWithUser(
            widget.list.uid,
            friendId,
          );
        } else {
          await widget.listShareService.unshareListWithUser(
            widget.list.uid,
            friendId,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(context, 'Friends updated');
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error updating friends: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.error(context, 'Failed to update friends');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Manage friends',
      confirmText: 'Save',
      onCancel: () => Navigator.pop(context),
      onConfirm: _isSaving ? null : _saveChanges,
      isLoading: _isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Select friends who can see "${widget.list.title}":',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: _filterFriends,
          ),
          const SizedBox(height: 16),

          // Friends list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'You don\'t have any friends yet.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            )
          else
            ..._filteredFriends.map((friend) {
              final isShared = _friendShareStatus[friend.friendUserId] ?? false;
              return _buildFriendTile(friend, isShared);
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Friend friend, bool isShared) {
    return InkWell(
      onTap: () {
        setState(() {
          _friendShareStatus[friend.friendUserId] = !isShared;
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
            // Avatar
            _buildAvatar(friend),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(friend.displayName, style: AppTypography.titleMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Friend friend) {
    if (friend.friendAvatarUrl != null && friend.friendAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
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
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        friend.initials,
        style: AppTypography.titleMedium.copyWith(color: color),
      ),
    );
  }
}

/// Animated arrow widget pointing to the Add list button
class _AnimatedArrow extends StatefulWidget {
  @override
  State<_AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<_AnimatedArrow>
    with TickerProviderStateMixin {
  late AnimationController _bubbleController;
  late AnimationController _arrowController;
  late Animation<double> _bubbleAnimation;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();

    // Bubble animation
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _bubbleAnimation = Tween<double>(begin: 20, end: 25).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeInOut),
    );

    // Arrow animation - slightly delayed for wobble effect
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Start arrow animation with a delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _arrowController.repeat(reverse: true);
      }
    });

    _arrowAnimation = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bubbleAnimation, _arrowAnimation]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bubble with text
            Transform.translate(
              offset: Offset(-15, _bubbleAnimation.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Text(
                      'Get started',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow with longer stalk pointing diagonally to FAB
            Transform.translate(
              offset: Offset(
                _arrowAnimation.value * 0.7,
                _arrowAnimation.value,
              ),
              child: CustomPaint(
                size: const Size(50, 50),
                painter: _DiagonalArrowPainter(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for diagonal arrow with long stalk and filled head
class _DiagonalArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    // Arrow tip position (bottom-right)
    final arrowTip = Offset(size.width, size.height);

    // Draw diagonal stalk from top-left to arrowhead base
    const startPoint = Offset(0, 0);
    final lineEnd = Offset(size.width - 10, size.height - 10);
    canvas.drawLine(startPoint, lineEnd, paint);

    // Draw filled triangular arrowhead
    final arrowPaint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy); // Tip
    arrowPath.lineTo(arrowTip.dx - 18, arrowTip.dy - 5); // Left edge
    arrowPath.lineTo(arrowTip.dx - 5, arrowTip.dy - 18); // Top edge
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
