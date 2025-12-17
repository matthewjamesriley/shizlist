import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/wish_list.dart';

/// List card widget for displaying wish lists
class ListCard extends StatelessWidget {
  final WishList list;
  final VoidCallback? onTap;
  final VoidCallback? onShareTap;

  const ListCard({
    super.key,
    required this.list,
    this.onTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with cover or gradient
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: list.coverImageUrl == null
                    ? AppColors.primaryGradient
                    : null,
                image: list.coverImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(list.coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Visibility badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            list.isPublic ? Icons.public : Icons.lock,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            list.isPublic ? 'Public' : 'Private',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    list.title,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (list.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      list.description!,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      // Item count
                      _buildStat(
                        icon: Icons.list_alt,
                        value: '${list.itemCount}',
                        label: 'items',
                      ),
                      const SizedBox(width: 16),
                      
                      // Claimed count
                      _buildStat(
                        icon: Icons.card_giftcard,
                        value: '${list.claimedCount}',
                        label: 'claimed',
                      ),
                      
                      const Spacer(),
                      
                      // Share button
                      IconButton(
                        onPressed: onShareTap,
                        icon: const Icon(Icons.share),
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Progress bar
                  if (list.itemCount > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: list.progressPercentage,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTypography.labelMedium,
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}


