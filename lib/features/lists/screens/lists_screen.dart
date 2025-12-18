import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/wish_list.dart';
import '../../../services/list_service.dart';
import '../../../services/lists_notifier.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/list_card.dart';
import '../widgets/create_list_dialog.dart';

/// Main lists screen showing user's wish lists
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  final ListsNotifier _listsNotifier = ListsNotifier();
  final ListService _listService = ListService();

  List<WishList> _lists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listsNotifier.addListener(_onListsChanged);
    _loadLists();
  }

  @override
  void dispose() {
    _listsNotifier.removeListener(_onListsChanged);
    super.dispose();
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
  }

  Future<void> _loadLists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final lists = await _listService.getUserLists();

      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onShareTap: () => _shareList(list),
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
                color: AppColors.textSecondary,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/No-Lists.png', width: 180, height: 180),
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
    );
  }

  Future<void> _refreshLists() async {
    await _loadLists();
  }

  void _openList(WishList list) {
    context.go('/lists/${list.uid}');
  }

  void _shareList(WishList list) {
    // TODO: Implement share functionality
    AppNotification.show(
      context,
      message: 'Share link: ${list.shareUrl}',
      icon: PhosphorIcons.link(),
    );
  }

  void _deleteList(WishList list) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete list?'),
            content: Text(
              'Are you sure you want to delete "${list.title}"? This action can be undone.',
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
}
