import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../widgets/item_card.dart';

/// List detail screen showing items in a wish list
class ListDetailScreen extends StatefulWidget {
  final String listUid;

  const ListDetailScreen({
    super.key,
    required this.listUid,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late WishList _list;
  List<ListItem> _items = [];
  bool _isLoading = true;
  final bool _isOwner = true; // TODO: Determine from auth

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    // TODO: Load from ListService and ItemService
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _list = WishList(
        id: 1,
        uid: widget.listUid,
        ownerId: 'user-1',
        title: 'My Birthday Wishlist',
        description: 'Things I would love to receive for my birthday!',
        visibility: ListVisibility.public,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        itemCount: 5,
        claimedCount: 2,
      );

      _items = [
        ListItem(
          id: 1,
          uid: 'item-1',
          listId: 1,
          name: 'Apple AirPods Pro',
          description: 'Wireless earbuds with noise cancellation',
          price: 249.99,
          category: ItemCategory.stuff,
          priority: ItemPriority.high,
          isClaimed: true,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        ListItem(
          id: 2,
          uid: 'item-2',
          listId: 1,
          name: 'Cooking Class Experience',
          description: 'Italian cuisine cooking class for 2',
          price: 150.00,
          category: ItemCategory.events,
          priority: ItemPriority.medium,
          isClaimed: false,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ListItem(
          id: 3,
          uid: 'item-3',
          listId: 1,
          name: 'Weekend Trip to Napa',
          description: 'Wine tasting and relaxation',
          price: 500.00,
          category: ItemCategory.trips,
          priority: ItemPriority.high,
          isClaimed: true,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ListItem(
          id: 4,
          uid: 'item-4',
          listId: 1,
          name: 'Handmade Scarf',
          description: 'Cozy wool scarf in blue',
          category: ItemCategory.homemade,
          priority: ItemPriority.low,
          isClaimed: false,
          createdAt: DateTime.now(),
        ),
        ListItem(
          id: 5,
          uid: 'item-5',
          listId: 1,
          name: 'Birthday Dinner',
          description: 'Favorite restaurant reservation',
          price: 100.00,
          category: ItemCategory.meals,
          priority: ItemPriority.medium,
          isClaimed: false,
          createdAt: DateTime.now(),
        ),
      ];

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: AppColors.error),
                  title: Text('Delete List', style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // List header with description
          if (_list.description != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceVariant,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _list.description!,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _list.isPublic ? Icons.public : Icons.lock,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _list.isPublic ? 'Public List' : 'Private List',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.list,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_list.itemCount} items',
                        style: AppTypography.bodySmall,
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
            child: _items.isEmpty
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _addItem(),
        child: const Icon(Icons.add, size: 36),
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
            Text(
              'No Items Yet',
              style: AppTypography.titleLarge,
            ),
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Sort',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Sort by',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Date Added'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Price'),
                  selected: false,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Priority'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Show',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Available'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Claimed'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        // TODO: Edit list
        break;
      case 'share':
        // TODO: Share list
        break;
      case 'delete':
        _confirmDeleteList();
        break;
    }
  }

  void _confirmDeleteList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${_list.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete list
              context.go('/lists');
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _openItemDetail(ListItem item) {
    // TODO: Navigate to item detail
  }

  void _claimItem(ListItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    context.push('/add-item/${_list.id}');
  }
}

