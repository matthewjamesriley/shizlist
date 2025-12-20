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
  final VoidCallback? onTap;
  final VoidCallback? onClaimTap;
  final ItemPosition position;

  const ItemCard({
    super.key,
    required this.item,
    this.isOwner = false,
    this.onTap,
    this.onClaimTap,
    this.position = ItemPosition.only,
  });

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
          top: position == ItemPosition.first || position == ItemPosition.only
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
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail image
              _buildThumbnail(),
              const SizedBox(width: 12),

              // Item details - left side
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryBadge(),
                    const SizedBox(height: 6),

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

                    // Claim status row (only if claimed)
                    if (!isOwner && item.isClaimed) ...[
                      const SizedBox(height: 8),
                      _buildClaimedBadge(),
                    ],
                  ],
                ),
              ),
              
              // Priority and price - right side
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPriorityBadge(),
                  if (item.price != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.formattedPrice,
                      style: AppTypography.priceText,
                    ),
                  ],
                ],
              ),

              // Claim button for gifters
              if (!isOwner && !item.isClaimed) ...[
                const SizedBox(width: 8),
                _buildClaimButton(),
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

  Widget _buildClaimedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.claimedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('CLAIMED', style: AppTypography.claimedBadge),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filled(
        onPressed: onClaimTap,
        icon: const Icon(Icons.card_giftcard),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
