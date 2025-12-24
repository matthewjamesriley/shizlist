import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/list_item.dart';

/// Position of item in a grouped list
enum ItemPosition { first, middle, last, only }

/// Item card widget for displaying wish list items
class ItemCard extends StatelessWidget {
  final ListItem item;
  final bool isOwner;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onCommitTap;
  final VoidCallback? onCommitStatusTap;
  final VoidCallback? onLinkTap;
  final ItemPosition position;

  const ItemCard({
    super.key,
    required this.item,
    this.isOwner = false,
    this.currentUserId,
    this.onTap,
    this.onCommitTap,
    this.onCommitStatusTap,
    this.onLinkTap,
    this.position = ItemPosition.only,
  });

  bool get _isCommittedByMe =>
      item.isClaimed && item.claimedByUserId == currentUserId;

  bool get _isPurchased => item.commitStatus == 'purchased';

  BorderRadius get _borderRadius {
    const radius = Radius.circular(12);
    switch (position) {
      case ItemPosition.first:
        return const BorderRadius.only(topLeft: radius, topRight: radius);
      case ItemPosition.last:
        return const BorderRadius.only(bottomLeft: radius, bottomRight: radius);
      case ItemPosition.middle:
        return BorderRadius.zero;
      case ItemPosition.only:
        return BorderRadius.circular(12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        border: Border(
          left: BorderSide(color: AppColors.divider, width: 1),
          right: BorderSide(color: AppColors.divider, width: 1),
          top:
              position == ItemPosition.first || position == ItemPosition.only
                  ? BorderSide(color: AppColors.divider, width: 1)
                  : BorderSide.none,
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category, link, priority, price (spans full width)
                Row(
                  children: [
                    _buildCategoryBadge(),
                    if (item.retailerUrl != null &&
                        item.retailerUrl!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildLinkButton(),
                    ],
                    const Spacer(),
                    // Priority and price on right
                    if (item.price != null) ...[
                      Text(item.formattedPrice, style: AppTypography.priceText),
                      const SizedBox(width: 6),
                    ],
                    _buildPriorityBadge(),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom section: Thumbnail, details, and commit button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Thumbnail image
                    _buildThumbnail(),
                    const SizedBox(width: 12),

                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name
                          Text(
                            item.name,
                            style: AppTypography.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (item.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: AppTypography.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                        ],
                      ),
                    ),

                    // Commit button for gifters (only if not committed)
                    if (!isOwner && !item.isClaimed) ...[
                      const SizedBox(width: 8),
                      _buildCommitButton(),
                    ],
                  ],
                ),

                // Commit status row at bottom (for anyone if item is committed)
                if (item.isClaimed) ...[
                  const SizedBox(height: 10),
                  _buildCommitStatusRow(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          item.thumbnailUrl != null
              ? CachedNetworkImage(
                imageUrl: item.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                errorWidget:
                    (context, url, error) => Icon(
                      item.category.icon,
                      color: AppColors.textHint,
                      size: 32,
                    ),
              )
              : Icon(item.category.icon, color: AppColors.textHint, size: 32),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: item.category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        item.category.displayName,
        style: AppTypography.categoryBadge.copyWith(color: item.category.color),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    return PhosphorIcon(
      item.priority.icon,
      size: 20,
      color: item.priority.color,
    );
  }

  Widget _buildCommitStatusRow() {
    final isPurchased = _isPurchased;
    final isMyCommit = _isCommittedByMe;
    final committerName = item.claimedByDisplayName?.split(' ').first ?? 'Someone';

    // Determine status text and icon
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isPurchased) {
      statusText = isMyCommit ? 'You purchased this' : '$committerName purchased this';
      statusIcon = Icons.shopping_bag;
      statusColor = AppColors.primary;
    } else {
      statusText = isMyCommit ? 'You committed to this' : '$committerName committed';
      statusIcon = Icons.check_circle;
      statusColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: onCommitStatusTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMyCommit
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.claimedBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 18, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: AppTypography.bodyMedium.copyWith(
                  color: isMyCommit ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isMyCommit ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // Arrow indicator to show it's tappable
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isMyCommit ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filled(
        onPressed: onCommitTap,
        icon: const Icon(Icons.card_giftcard),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnPrimary,
        ),
      ),
    );
  }

  Widget _buildLinkButton() {
    return GestureDetector(
      onTap: onLinkTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Go to link',
          style: AppTypography.categoryBadge.copyWith(color: AppColors.accent),
        ),
      ),
    );
  }
}
