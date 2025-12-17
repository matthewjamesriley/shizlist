import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../routing/app_router.dart';
import 'app_drawer.dart';
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
                ? const ShizListLogo(height: 32)
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
                label: 'My Lists',
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
              ? FloatingActionButton.large(
                onPressed: () {
                  // TODO: Navigate to add item with current list
                  _showAddItemSheet(context);
                },
                child: const Icon(Icons.add, size: 36),
              )
              : null,
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'My Lists';
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

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) =>
                    _QuickAddSheet(scrollController: scrollController),
          ),
    );
  }
}

/// Quick add sheet for creating new items
class _QuickAddSheet extends StatefulWidget {
  final ScrollController scrollController;

  const _QuickAddSheet({required this.scrollController});

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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Text('Add Item', style: AppTypography.titleLarge),
                TextButton(onPressed: _saveItem, child: const Text('Save')),
              ],
            ),
          ),

          const Divider(height: 1),

          // Form
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'What do you want?',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add more details (optional)',
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Price field
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: '0.00',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // URL field
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Product URL',
                        hintText: 'Paste link (optional)',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),

                    // Category selection
                    Text('Category', style: AppTypography.labelLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _categories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = category);
                                }
                              },
                              selectedColor: AppColors.claimedBackground,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
