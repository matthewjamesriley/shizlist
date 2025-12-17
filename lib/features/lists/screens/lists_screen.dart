import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/wish_list.dart';
import '../../../widgets/list_card.dart';
import '../widgets/create_list_dialog.dart';

/// Main lists screen showing user's wish lists
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  // TODO: Replace with actual data from ListService
  final List<WishList> _lists = [
    WishList(
      id: 1,
      uid: 'sample-list-1',
      ownerId: 'user-1',
      title: 'My Birthday Wishlist',
      description: 'Things I would love to receive for my birthday!',
      visibility: ListVisibility.public,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      itemCount: 12,
      claimedCount: 4,
    ),
    WishList(
      id: 2,
      uid: 'sample-list-2',
      ownerId: 'user-1',
      title: 'Holiday Gift Ideas',
      description: 'Gifts for the holiday season',
      visibility: ListVisibility.private,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      itemCount: 8,
      claimedCount: 2,
    ),
    WishList(
      id: 3,
      uid: 'sample-list-3',
      ownerId: 'user-1',
      title: 'Home Improvement',
      visibility: ListVisibility.private,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      itemCount: 5,
      claimedCount: 0,
    ),
  ];

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_lists.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshLists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _lists.length + 1, // +1 for create button
        itemBuilder: (context, index) {
          if (index == _lists.length) {
            return _buildCreateListButton();
          }

          final list = _lists[index];
          return ListCard(
            list: list,
            onTap: () => _openList(list),
            onShareTap: () => _shareList(list),
          );
        },
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.claimedBackground,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Lists Yet',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first wish list and start sharing the stuff you want!',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewList,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First List'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateListButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: _createNewList,
        icon: const Icon(Icons.add),
        label: const Text('Create New List'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _refreshLists() async {
    setState(() => _isLoading = true);
    
    // TODO: Fetch lists from ListService
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() => _isLoading = false);
  }

  void _openList(WishList list) {
    context.go('/lists/${list.uid}');
  }

  void _shareList(WishList list) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link: ${list.shareUrl}'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // TODO: Copy to clipboard
          },
        ),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${result.title}"'),
          ),
        );
      }
    }
  }
}


