import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/lists/widgets/create_list_dialog.dart';
import '../models/user_profile.dart';
import '../routing/app_router.dart';
import '../services/auth_service.dart';
import '../services/list_service.dart';
import '../services/lists_notifier.dart';
import '../services/user_settings_service.dart';
import 'add_item_sheet.dart';
import 'app_drawer.dart';
import 'app_notification.dart';
import 'item_search_delegate.dart';
import 'shizlist_logo.dart';

/// Main app shell with bottom navigation and drawer
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _listService = ListService();
  final _listsNotifier = ListsNotifier();
  bool _showButtons = false;
  bool _hasLists = false;
  bool _hasItems = false;
  UserProfile? _userProfile;
  
  // Bouncing arrow animation
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkHasListsAndItems();
    // Listen for profile updates
    UserSettingsService().addListener(_onSettingsChanged);
    // Listen for list changes
    _listsNotifier.addListener(_onListsChanged);
    // Delay showing buttons to avoid spin animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showButtons = true);
      }
    });
    
    // Setup bouncing arrow animation
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    _arrowAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    UserSettingsService().removeListener(_onSettingsChanged);
    _listsNotifier.removeListener(_onListsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    _loadUserProfile();
  }

  void _onListsChanged() {
    // Always refresh list/item count when notifier fires
    // (list might have been added/deleted, or items changed)
    _checkHasListsAndItems();
    
    // When an item is added, immediately mark as having items
    if (_listsNotifier.itemCountChanged) {
      setState(() => _hasItems = true);
    }
  }

  Future<void> _checkHasListsAndItems() async {
    try {
      final lists = await _listService.getUserLists();
      if (mounted) {
        // Check if any list has items
        final totalItems = lists.fold<int>(0, (sum, list) => sum + list.itemCount);
        setState(() {
          _hasLists = lists.isNotEmpty;
          _hasItems = totalItems > 0;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() => _userProfile = profile);
      }
    } catch (e) {
      // Silently fail - will show icon instead
    }
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.lists)) return 0;
    if (location == AppRoutes.contacts) return 1;
    if (location == AppRoutes.invite) return 2;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.lists);
        break;
      case 1:
        context.go(AppRoutes.contacts);
        break;
      case 2:
        context.go(AppRoutes.invite);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
          onPressed: () => _openSearch(context),
        ),
        title:
            currentIndex == 0
                ? Transform.translate(
                  offset: const Offset(0, -4),
                  child: const ShizListLogo(height: 32),
                )
                : Text(
                  _getTitle(currentIndex),
                  style: AppTypography.titleLarge,
                ),
        centerTitle: true,
        actions: [
          // Messages icon - commented out for later use
          // IconButton(
          //   icon: PhosphorIcon(PhosphorIcons.chatCircleText()),
          //   onPressed: () => context.go(AppRoutes.messages),
          //   tooltip: 'Messages',
          // ),
          // Profile picture that opens drawer
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _userProfile?.avatarUrl != null
                      ? Image.network(
                          _userProfile!.avatarUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: PhosphorIcon(
                              PhosphorIcons.user(),
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        )
                      : Center(
                          child: PhosphorIcon(
                            PhosphorIcons.user(),
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Space for tab bar
        child: widget.child,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onTabTapped(context, index),
            destinations: [
              NavigationDestination(
                icon: PhosphorIcon(PhosphorIcons.star()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.star(PhosphorIconsStyle.fill),
                ),
                label: 'My lists',
              ),
              NavigationDestination(
                icon: PhosphorIcon(PhosphorIcons.users()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.users(PhosphorIconsStyle.fill),
                ),
                label: 'My friends',
              ),
              NavigationDestination(
                icon: PhosphorIcon(PhosphorIcons.userPlus()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.userPlus(PhosphorIconsStyle.fill),
                ),
                label: 'Invite',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: (_showButtons && currentIndex == 0) ? Offset.zero : const Offset(0, 0.3),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: (_showButtons && currentIndex == 0) ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !_showButtons || currentIndex != 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Add List button (left)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: ClipRRect(
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
                          onTap: _showCreateListDialog,
                          borderRadius: BorderRadius.circular(32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                            child: Text(
                              'Add list',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Add Item button (right) - Orange (disabled if no lists)
                // With bouncing arrow when lists exist but no items
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Bouncing arrow (positioned above the button)
                    if (_hasLists && !_hasItems)
                      Positioned(
                        top: -46,
                        child: AnimatedBuilder(
                          animation: _arrowAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _arrowAnimation.value),
                            child: PhosphorIcon(
                              PhosphorIcons.arrowDown(PhosphorIconsStyle.bold),
                              size: 36,
                              color: Colors.black,
                            ),
                            );
                          },
                        ),
                      ),
                    Material(
                      color: _hasLists ? AppColors.accent : Colors.grey.shade400,
                      shape: const CircleBorder(),
                      elevation: _hasLists ? 6 : 2,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      child: InkWell(
                        onTap: _hasLists ? () => _showAddItemSheet(context) : null,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: PhosphorIcon(
                            PhosphorIcons.plus(),
                            size: 28,
                            color: _hasLists ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'My lists';
      case 1:
        return 'My friends';
      case 2:
        return 'Invite';
      default:
        return 'ShizList';
    }
  }

  void _showCreateListDialog() async {
    final result = await CreateListDialog.show(context);

    if (result != null && mounted) {
      // Immediately enable the + button since we now have a list
      setState(() => _hasLists = true);
      ListsNotifier().notifyListAdded(result);
      AppNotification.success(context, 'Created "${result.title}"');
    }
  }

  void _showAddItemSheet(BuildContext context) {
    AddItemSheet.show(context);
  }

  void _openSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: ItemSearchDelegate(),
    );
  }
}
