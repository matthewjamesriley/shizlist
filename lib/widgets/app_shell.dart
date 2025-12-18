import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/lists/widgets/create_list_dialog.dart';
import '../routing/app_router.dart';
import '../services/lists_notifier.dart';
import 'add_item_sheet.dart';
import 'app_drawer.dart';
import 'app_notification.dart';
import 'shizlist_logo.dart';

/// Main app shell with bottom navigation and drawer
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.lists)) return 0;
    if (location == AppRoutes.invite) return 1;
    if (location == AppRoutes.contacts) return 2;
    if (location == AppRoutes.share) return 3;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.lists);
        break;
      case 1:
        context.go(AppRoutes.invite);
        break;
      case 2:
        context.go(AppRoutes.contacts);
        break;
      case 3:
        context.go(AppRoutes.share);
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
          onPressed: () {
            // TODO: Open search
          },
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
          // Messages icon
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.chatCircleText()),
            onPressed: () => context.go(AppRoutes.messages),
            tooltip: 'Messages',
          ),
          // Profile picture that opens drawer
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: PhosphorIcon(
                  PhosphorIcons.user(),
                  color: AppColors.textOnPrimary,
                  size: 20,
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
                icon: PhosphorIcon(PhosphorIcons.userPlus()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.userPlus(PhosphorIconsStyle.fill),
                ),
                label: 'Invite',
              ),
              NavigationDestination(
                icon: PhosphorIcon(PhosphorIcons.addressBook()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.addressBook(PhosphorIconsStyle.fill),
                ),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: PhosphorIcon(PhosphorIcons.shareFat()),
                selectedIcon: PhosphorIcon(
                  PhosphorIcons.shareFat(PhosphorIconsStyle.fill),
                ),
                label: 'Share',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton:
          currentIndex == 0
              ? Row(
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
                  // Add Item button (right) - Orange
                  FloatingActionButton(
                    heroTag: 'addItem',
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _showAddItemSheet(context);
                    },
                    child: PhosphorIcon(PhosphorIcons.plus(), size: 28),
                  ),
                ],
              )
              : null,
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'My lists';
      case 1:
        return 'Invite';
      case 2:
        return 'Contacts';
      case 3:
        return 'Share';
      default:
        return 'ShizList';
    }
  }

  void _showCreateListDialog() async {
    final result = await CreateListDialog.show(context);

    if (result != null && mounted) {
      ListsNotifier().notifyListAdded(result);
      AppNotification.success(context, 'Created "${result.title}"');
    }
  }

  void _showAddItemSheet(BuildContext context) {
    AddItemSheet.show(context);
  }
}
