import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/lists/widgets/create_list_dialog.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../models/user_profile.dart';
import '../routing/app_router.dart';
import '../services/auth_service.dart';
import '../services/list_service.dart';
import '../services/lists_notifier.dart';
import '../services/notification_service.dart';
import '../services/user_settings_service.dart';
import '../services/page_load_notifier.dart';
import '../services/view_mode_notifier.dart';
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

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  final _listService = ListService();
  final _listsNotifier = ListsNotifier();
  final _viewModeNotifier = ViewModeNotifier();
  final _pageLoadNotifier = PageLoadNotifier();
  final _notificationService = NotificationService();
  bool _showButtons = false;
  bool _hasLists = false;
  bool _hasItems = false;
  bool _isFabMenuOpen = false;
  UserProfile? _userProfile;
  int _lastIndex = 0;
  int _unreadNotifications = 0;

  // FAB menu animation
  late AnimationController _fabMenuController;
  late Animation<double> _fabMenuAnimation;

  // FAB menu item 2 (staggered) animation
  late AnimationController _fabMenuItem2Controller;
  late Animation<double> _fabMenuItem2Animation;

  // FAB pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkHasListsAndItems();
    _initNotifications();
    // Listen for profile updates
    UserSettingsService().addListener(_onSettingsChanged);
    // Listen for list changes
    _listsNotifier.addListener(_onListsChanged);
    // Listen for page load to show buttons
    _pageLoadNotifier.addListener(_onPageLoaded);

    // Setup FAB menu animation
    _fabMenuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabMenuAnimation = CurvedAnimation(
      parent: _fabMenuController,
      curve: Curves.easeOut,
    );

    // Setup staggered FAB menu item 2 animation (300ms delay)
    _fabMenuItem2Controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabMenuItem2Animation = CurvedAnimation(
      parent: _fabMenuItem2Controller,
      curve: Curves.easeOut,
    );

    // Setup FAB pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  void _onPageLoaded() {
    if (_pageLoadNotifier.listsPageLoaded && mounted) {
      // Small delay for smooth entrance after content renders
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() => _showButtons = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _fabMenuController.dispose();
    _fabMenuItem2Controller.dispose();
    _pulseController.dispose();
    UserSettingsService().removeListener(_onSettingsChanged);
    _listsNotifier.removeListener(_onListsChanged);
    _pageLoadNotifier.removeListener(_onPageLoaded);
    super.dispose();
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabMenuOpen = !_isFabMenuOpen;
      if (_isFabMenuOpen) {
        _fabMenuController.forward();
        // Start second button animation with 150ms delay
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _isFabMenuOpen) {
            _fabMenuItem2Controller.forward();
          }
        });
      } else {
        _fabMenuItem2Controller.reverse();
        _fabMenuController.reverse();
      }
    });
  }

  void _closeFabMenu() {
    if (_isFabMenuOpen) {
      setState(() {
        _isFabMenuOpen = false;
        _fabMenuItem2Controller.reverse();
        _fabMenuController.reverse();
      });
    }
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
        final totalItems = lists.fold<int>(
          0,
          (sum, list) => sum + list.itemCount,
        );
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

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    _notificationService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() => _unreadNotifications = count);
      }
    });
    // Set initial count
    if (mounted) {
      setState(() => _unreadNotifications = _notificationService.unreadCount);
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
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

    // Reset button state when navigating away from lists page
    if (currentIndex != 0 && _lastIndex == 0) {
      _showButtons = false;
      _pageLoadNotifier.resetListsPageLoaded();
    }
    _lastIndex = currentIndex;

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
          // Notifications bell icon with badge
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _openNotifications,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textPrimary, width: 1.5),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.bell(),
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
                  border: Border.all(color: AppColors.textPrimary, width: 1.5),
                ),
                child: ClipOval(
                  child:
                      _userProfile?.avatarUrl != null
                          ? Image.network(
                            _userProfile!.avatarUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Center(
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
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
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
      floatingActionButton:
          currentIndex == 0
              ? AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: _showButtons ? Offset.zero : const Offset(0, 0.3),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showButtons ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showButtons,
                    child: _buildListsPageButtons(context),
                  ),
                ),
              )
              : const SizedBox.shrink(),
      floatingActionButtonAnimator: const NoFabAnimator(),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'My lists';
      case 1:
        return 'My friends';
      case 2:
        return 'Invite friends';
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
    showSearch(context: context, delegate: ItemSearchDelegate());
  }

  Widget _buildListsPageButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // View toggle button (left)
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
                  onTap: () {
                    setState(() {
                      _viewModeNotifier.toggle();
                    });
                  },
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: PhosphorIcon(
                      _viewModeNotifier.isCompactView
                          ? PhosphorIcons.rows()
                          : PhosphorIcons.squaresFour(),
                      size: 22,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Speed dial FAB (right)
        SizedBox(
          width: _isFabMenuOpen ? 300 : 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // Menu items (animated) - appear to the left
              if (_isFabMenuOpen) ...[
                // Add List option - furthest left
                Positioned(
                  right: _hasLists ? 165 : 70,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(_fabMenuAnimation),
                    child: FadeTransition(
                      opacity: _fabMenuAnimation,
                      child: _buildFabMenuItem(
                        label: 'Add list',
                        onTap: () {
                          _closeFabMenu();
                          _showCreateListDialog();
                        },
                      ),
                    ),
                  ),
                ),
                // Add Item option (only if has lists) - closer to FAB, staggered animation
                if (_hasLists)
                  Positioned(
                    right: 70,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(_fabMenuItem2Animation),
                      child: FadeTransition(
                        opacity: _fabMenuItem2Animation,
                        child: _buildFabMenuItem(
                          label: 'Add item',
                          onTap: () {
                            _closeFabMenu();
                            _showAddItemSheet(context);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
              // Main FAB button with pulse effect
              Positioned(
                right: -12,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse rings (only show when menu is closed and no items yet)
                      if (!_isFabMenuOpen && !_hasItems) ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            // Ease out the size expansion
                            final easedValue = Curves.easeOut.transform(
                              _pulseAnimation.value,
                            );
                            return Container(
                              width: 56 + (40 * easedValue),
                              height: 56 + (40 * easedValue),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.7 * (1 - easedValue),
                                  ),
                                  width: 6,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      // Actual FAB
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color:
                              _isFabMenuOpen ? Colors.black : AppColors.accent,
                          shape: const CircleBorder(),
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          child: InkWell(
                            onTap: _toggleFabMenu,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0,
                                  end: _isFabMenuOpen ? 0.125 : 0,
                                ),
                                duration: const Duration(milliseconds: 200),
                                builder: (context, value, child) {
                                  return Transform.rotate(
                                    angle: value * 2 * 3.14159,
                                    child: child,
                                  );
                                },
                                child: PhosphorIcon(
                                  PhosphorIcons.plus(),
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFabMenuItem({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Material(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom FAB animator that does no animation (instant show/hide)
class NoFabAnimator extends FloatingActionButtonAnimator {
  const NoFabAnimator();

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) {
    return end;
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    return const AlwaysStoppedAnimation(1.0);
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    return const AlwaysStoppedAnimation(1.0);
  }
}
