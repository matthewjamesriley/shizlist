import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../services/list_service.dart';
import '../../../services/lists_notifier.dart';
import '../../../widgets/add_item_sheet.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/bottom_sheet_header.dart';
import '../../../widgets/item_card.dart';

/// List detail screen showing items in a wish list
class ListDetailScreen extends StatefulWidget {
  final String listUid;

  const ListDetailScreen({super.key, required this.listUid});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen>
    with SingleTickerProviderStateMixin {
  late WishList _list;
  List<ListItem> _items = [];
  bool _isLoading = true;
  final bool _isOwner = true; // TODO: Determine from auth
  String _sortOption = 'newest';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadList();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    try {
      // Fetch the actual list from Supabase
      final list = await ListService().getListByUid(widget.listUid);

      if (list == null) {
        if (mounted) {
          context.go('/lists');
        }
        return;
      }

      setState(() {
        _list = list;
        // TODO: Load items from ItemService
        _items = [];
        _isLoading = false;
      });

      // Start fade-in animation after content loads
      _fadeController.forward();
    } catch (e) {
      debugPrint('Error loading list: $e');
      if (mounted) {
        context.go('/lists');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
            onPressed: () => context.go('/lists'),
          ),
        ),
        body:
            const SizedBox.shrink(), // Empty instead of spinner for smoother transition
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => context.go('/lists'),
        ),
        title: Text(_list.title, style: const TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: _handleMenuAction,
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.pencilSimple(),
                          size: 22,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Text('Edit list', style: AppTypography.bodyLarge),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.trash(),
                          size: 22,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete list',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // List header with description
            if (_list.description != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.surfaceVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _list.description!,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side - public/private and item count
                        Row(
                          children: [
                            Icon(
                              _list.isPublic ? Icons.public : Icons.lock,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _list.isPublic ? 'Public' : 'Private',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${_list.itemCount} items',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        // Right side - Sort dropdown
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() => _sortOption = value);
                            // TODO: Apply sorting to _items
                          },
                          offset: const Offset(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getSortLabel(_sortOption),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              PhosphorIcon(
                                PhosphorIcons.caretDown(),
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                            ],
                          ),
                          itemBuilder: (context) => [
                            _buildSortMenuItem('priority_high', 'Priority: High to Low'),
                            _buildSortMenuItem('priority_low', 'Priority: Low to High'),
                            const PopupMenuDivider(),
                            _buildSortMenuItem('price_high', 'Price: High to Low'),
                            _buildSortMenuItem('price_low', 'Price: Low to High'),
                            const PopupMenuDivider(),
                            _buildSortMenuItem('newest', 'Newest First'),
                            _buildSortMenuItem('oldest', 'Oldest First'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  const SizedBox(width: 8),
                  ...ItemCategory.values.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.displayName),
                        selected: false,
                        onSelected: (_) {},
                        avatar: Icon(
                          category.icon,
                          size: 16,
                          color: category.color,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Items list
            Expanded(
              child:
                  _items.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                        onRefresh: _loadList,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ItemCard(
                              item: item,
                              isOwner: _isOwner,
                              onTap: () => _openItemDetail(item),
                              onClaimTap: () => _claimItem(item),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => _addItem(),
        child: PhosphorIcon(PhosphorIcons.plus(), size: 28),
      ),
    );
  }

  String _getSortLabel(String option) {
    switch (option) {
      case 'priority_high':
        return 'Priority High';
      case 'priority_low':
        return 'Priority Low';
      case 'price_high':
        return 'Price High';
      case 'price_low':
        return 'Price Low';
      case 'newest':
        return 'Newest';
      case 'oldest':
        return 'Oldest';
      default:
        return 'Sort';
    }
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    final isSelected = _sortOption == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            PhosphorIcon(
              PhosphorIcons.check(),
              size: 18,
              color: AppColors.primary,
            )
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
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
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text('No Items Yet', style: AppTypography.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add items to your list using the + button',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _showEditListSheet();
        break;
      case 'delete':
        _confirmDeleteList();
        break;
    }
  }

  void _showEditListSheet() {
    final titleController = TextEditingController(text: _list.title);
    final descriptionController = TextEditingController(
      text: _list.description ?? '',
    );
    var visibility = _list.visibility;
    var isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> handleSave() async {
                if (titleController.text.trim().isEmpty) return;

                setSheetState(() => isLoading = true);

                try {
                  final updatedList = await ListService().updateList(
                    uid: _list.uid,
                    title: titleController.text.trim(),
                    description:
                        descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                    visibility: visibility,
                  );

                  setState(() {
                    _list = updatedList;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    AppNotification.success(context, 'List updated');
                  }
                } catch (e) {
                  setSheetState(() => isLoading = false);
                  if (mounted) {
                    AppNotification.show(
                      context,
                      message: 'Failed to update: $e',
                      icon: PhosphorIcons.warning(),
                      backgroundColor: AppColors.error,
                    );
                  }
                }
              }

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
                    // Shared header component
                    BottomSheetHeader(
                      title: 'Edit list',
                      confirmText: 'Save',
                      onCancel: () => Navigator.pop(context),
                      onConfirm: handleSave,
                      isLoading: isLoading,
                    ),

                    // Form content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title field
                            TextFormField(
                              controller: titleController,
                              style: AppTypography.titleMedium,
                              decoration: const InputDecoration(
                                hintText: 'List name',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description field
                            TextFormField(
                              controller: descriptionController,
                              style: AppTypography.titleMedium,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Description (optional)',
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Visibility
                            Text(
                              'Visibility',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Private option
                            GestureDetector(
                              onTap:
                                  () => setSheetState(
                                    () => visibility = ListVisibility.private,
                                  ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        visibility == ListVisibility.private
                                            ? AppColors.primary
                                            : AppColors.divider,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIcons.lock(),
                                      size: 28,
                                      color:
                                          visibility == ListVisibility.private
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Private',
                                            style: AppTypography.titleMedium,
                                          ),
                                          Text(
                                            'Only people you share with can see',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (visibility == ListVisibility.private)
                                      PhosphorIcon(
                                        PhosphorIcons.checkCircle(
                                          PhosphorIconsStyle.fill,
                                        ),
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Public option
                            GestureDetector(
                              onTap:
                                  () => setSheetState(
                                    () => visibility = ListVisibility.public,
                                  ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        visibility == ListVisibility.public
                                            ? AppColors.primary
                                            : AppColors.divider,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIcons.globe(),
                                      size: 28,
                                      color:
                                          visibility == ListVisibility.public
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Public',
                                            style: AppTypography.titleMedium,
                                          ),
                                          Text(
                                            'Anyone with the link can see',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (visibility == ListVisibility.public)
                                      PhosphorIcon(
                                        PhosphorIcons.checkCircle(
                                          PhosphorIconsStyle.fill,
                                        ),
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _confirmDeleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete list?'),
            content: Text(
              'Are you sure you want to delete "${_list.title}"? This action can be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await ListService().deleteList(_list.uid);
        // Notify the lists screen to remove this list from UI
        ListsNotifier().notifyListDeleted(_list.uid);
        if (mounted) {
          AppNotification.success(context, 'Deleted "${_list.title}"');
          context.go('/lists');
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

  void _openItemDetail(ListItem item) {
    // TODO: Navigate to item detail
  }

  void _claimItem(ListItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Claim Item'),
            content: Text('Do you want to claim "${item.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Claim item
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Claimed "${item.name}"')),
                  );
                },
                child: const Text('Claim'),
              ),
            ],
          ),
    );
  }

  void _addItem() {
    AddItemSheet.show(context, selectedList: _list);
  }
}
