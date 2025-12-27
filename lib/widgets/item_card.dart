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
  final VoidCallback? onPurchaseStatusTap;
  final VoidCallback? onLinkTap;
  final VoidCallback? onPriorityTap;
  final ItemPosition position;
  final bool notifyOnCommit;
  final bool notifyOnPurchase;

  const ItemCard({
    super.key,
    required this.item,
    this.isOwner = false,
    this.currentUserId,
    this.onTap,
    this.onCommitTap,
    this.onCommitStatusTap,
    this.onPurchaseStatusTap,
    this.onLinkTap,
    this.onPriorityTap,
    this.position = ItemPosition.only,
    this.notifyOnCommit = true,
    this.notifyOnPurchase = true,
  });

  bool get _isCommittedByMe =>
      item.isClaimed && item.claimedByUserId == currentUserId;

  bool get _isPurchasedByMe =>
      item.isPurchased && item.purchasedByUserId == currentUserId;

  // Check if purchased (either via commit status OR purchases table)
  bool get _isPurchased => item.commitStatus == 'purchased' || item.isPurchased;

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
                    // Priority and price on right - tappable area for owners
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (isOwner && onPriorityTap != null) ? onPriorityTap : null,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.price != null) ...[
                              Text(item.formattedPrice, style: AppTypography.priceText),
                              const SizedBox(width: 6),
                            ],
                            _buildPriorityBadge(),
                          ],
                        ),
                      ),
                    ),
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

                // Commit/Purchase status row at bottom (if item is committed or purchased)
                if (item.isClaimed || item.isPurchased) ...[
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
    final isCommitted = item.isClaimed;
    final isPurchased = _isPurchased;
    final isMyCommit = _isCommittedByMe;
    final isMyPurchase = _isPurchasedByMe;
    final committerName = item.claimedByDisplayName?.split(' ').first ?? 'Someone';
    final purchaserName = item.purchasedByDisplayName?.split(' ').first ?? 'Someone';

    String getCommitText() {
      if (isMyCommit) return 'You committed';
      // For owners: show name only if notifyOnCommit is enabled
      if (isOwner && !notifyOnCommit) return 'Someone committed';
      return '$committerName committed';
    }

    String getPurchaseText() {
      if ((item.isPurchased && isMyPurchase) || (!item.isPurchased && isMyCommit)) {
        return 'You purchased';
      }
      // For owners: show name only if notifyOnPurchase is enabled
      if (isOwner && !notifyOnPurchase) return 'Someone purchased';
      return item.isPurchased ? '$purchaserName purchased' : '$committerName purchased';
    }

    return Row(
      children: [
        // Committed badge (amber) - show if committed
        if (isCommitted) ...[
          GestureDetector(
            onTap: onCommitStatusTap,
            child: _buildStatusBadge(
              text: getCommitText(),
              icon: Icons.check_circle,
              backgroundColor: Colors.amber.shade100,
              textColor: Colors.brown.shade800,
              iconColor: Colors.brown.shade700,
            ),
          ),
        ],
        
        // Purchased badge (teal bg, white text) - show if purchased
        if (isPurchased) ...[
          if (isCommitted) const SizedBox(width: 8),
          GestureDetector(
            onTap: onPurchaseStatusTap ?? onCommitStatusTap,
            child: _buildStatusBadge(
              text: getPurchaseText(),
              icon: Icons.shopping_bag,
              backgroundColor: AppColors.primary,
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
          ),
        ],
        
        const Spacer(),
      ],
    );
  }
  
  Widget _buildStatusBadge({
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
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
