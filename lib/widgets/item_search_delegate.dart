import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/item_service.dart';
import 'app_notification.dart';
import 'edit_item_sheet.dart';

/// Search delegate for searching items across all lists
class ItemSearchDelegate extends SearchDelegate<ItemSearchResult?> {
  final ItemService _itemService = ItemService();
  Timer? _debounceTimer;
  
  ItemSearchDelegate() : super(
    searchFieldLabel: 'Search all items...',
    searchFieldStyle: AppTypography.bodyLarge.copyWith(
      color: AppColors.textPrimary,
    ),
  );

  /// Force refresh of search results by re-running query
  void _forceRefresh(BuildContext context) {
    final currentQuery = query;
    // Temporarily clear query to force widget rebuild
    query = '';
    // Use microtask to ensure the query change is processed
    Future.microtask(() {
      query = currentQuery;
      showResults(context);
    });
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: PhosphorIcon(PhosphorIcons.x()),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: PhosphorIcon(PhosphorIcons.arrowLeft()),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptyState();
    }
    return _buildSearchResults(context);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIcons.magnifyingGlass(),
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search your items',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find items across all your lists',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<ItemSearchResult>>(
      future: _itemService.searchAllItems(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIcons.warning(),
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIcons.magnifyingGlass(),
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No items found',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            return _buildResultTile(context, result);
          },
        );
      },
    );
  }

  Widget _buildResultTile(BuildContext context, ItemSearchResult result) {
    final item = result.item;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.surfaceVariant,
        ),
        clipBehavior: Clip.antiAlias,
        child: item.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: item.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: PhosphorIcon(
                    PhosphorIcons.image(),
                    color: AppColors.textPrimary,
                  ),
                ),
              )
            : Center(
                child: PhosphorIcon(
                  item.category.icon,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
      ),
      title: Text(
        item.name,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.listTitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.price != null) ...[
            const SizedBox(height: 2),
            Text(
              item.formattedPrice,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      trailing: PhosphorIcon(
        item.priority.icon,
        color: item.priority.color,
        size: 22,
      ),
      onTap: () {
        // Open the edit item sheet without closing search
        EditItemSheet.show(
          context,
          item: result.item,
          onSaved: () {
            AppNotification.success(context, 'Item updated');
            // Force full refresh by toggling query
            _forceRefresh(context);
          },
          onDeleted: () async {
            // Confirm and delete the item
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete item?'),
                content: Text('Are you sure you want to delete "${result.item.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            
            if (confirmed == true) {
              try {
                await ItemService().deleteItem(result.item.uid);
                AppNotification.success(context, 'Item deleted');
                // Force full refresh by toggling query
                _forceRefresh(context);
              } catch (e) {
                AppNotification.error(context, 'Failed to delete item');
              }
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

