import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/lists/widgets/create_list_dialog.dart';
import '../routing/app_router.dart';
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
          icon: const Icon(Icons.search),
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
            icon: const Icon(Icons.message_outlined),
            onPressed: () => context.go(AppRoutes.messages),
            tooltip: 'Messages',
          ),
          // Profile picture that opens drawer
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.person,
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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.star_outline),
                selectedIcon: Icon(Icons.star),
                label: 'My lists',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_add_outlined),
                selectedIcon: Icon(Icons.person_add),
                label: 'Invite',
              ),
              NavigationDestination(
                icon: Icon(Icons.contacts_outlined),
                selectedIcon: Icon(Icons.contacts),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: Icon(Icons.share_outlined),
                selectedIcon: Icon(Icons.share),
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
                    child: const Icon(Icons.add, size: 28),
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
      AppNotification.success(context, 'Created "${result.title}"');
    }
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => const _QuickAddSheet(),
    );
  }
}

/// Quick add sheet for creating new items
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedCategory = 'Stuff';
  bool _isLoading = false;

  final List<String> _categories = [
    'Stuff',
    'Events',
    'Trips',
    'Homemade',
    'Meals',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Header with black background
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Title - centered
                Text(
                  'Add item',
                  style: AppTypography.titleLarge.copyWith(color: Colors.white),
                ),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    // Save button - prominent pill style
                    GestureDetector(
                      onTap: _isLoading ? null : _saveItem,
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
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  'Add',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'Item name'),
                      textCapitalization: TextCapitalization.words,
                      style: AppTypography.titleMedium,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                      ),
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 24),

                    // Price field
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        hintText: 'Price',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 24),

                    // URL field
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'Product URL (optional)',
                      ),
                      keyboardType: TextInputType.url,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 32),

                    // Category selection
                    Text('Category', style: AppTypography.titleMedium),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _categories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return GestureDetector(
                              onTap:
                                  () => setState(
                                    () => _selectedCategory = category,
                                  ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.claimedBackground
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.divider,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  category,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Amazon search option
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          // TODO: Open Amazon search
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Or, Search on Amazon'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save item via ItemService
      Navigator.pop(context);
      AppNotification.success(context, 'Item added!');
    }
  }
}
