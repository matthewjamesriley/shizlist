import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/wish_list.dart';
import 'app_dialog.dart';

/// List card widget for displaying wish lists
class ListCard extends StatefulWidget {
  final WishList list;
  final VoidCallback? onTap;
  final VoidCallback? onShareTap;
  final Function(bool isPublic)? onVisibilityChanged;

  const ListCard({
    super.key,
    required this.list,
    this.onTap,
    this.onShareTap,
    this.onVisibilityChanged,
  });

  @override
  State<ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<ListCard> {
  bool _isImageExpanded = false;

  void _toggleImageExpanded() {
    setState(() {
      _isImageExpanded = !_isImageExpanded;
    });
  }

  void _showVisibilityDialog() async {
    final isCurrentlyPublic = widget.list.isPublic;
    final listTitle = widget.list.title;

    final confirmed = await AppDialog.show(
      context,
      title: isCurrentlyPublic
          ? 'Make "$listTitle" private?'
          : 'Make "$listTitle" public?',
      content: isCurrentlyPublic
          ? 'Only people you share with will be able to see it.'
          : 'Anyone with the link will be able to see it.',
    );

    if (confirmed) {
      widget.onVisibilityChanged?.call(!isCurrentlyPublic);
    }
  }

  String _getEventDateLabel() {
    if (!widget.list.hasEventDate) return '';
    
    final days = widget.list.daysUntilEvent;
    if (days == null) return '';
    
    if (days == 0) {
      return 'Today!';
    } else if (days == 1) {
      return 'Tomorrow';
    } else if (days < 0) {
      return widget.list.isRecurring ? '${-days}d ago' : 'Passed';
    } else if (days <= 7) {
      return 'In ${days}d';
    } else if (days <= 30) {
      final weeks = (days / 7).floor();
      return weeks == 1 ? 'In 1 wk' : 'In ${weeks}wk';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final date = widget.list.nextEventDate!;
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with cover or gradient
            Container(
              height: _isImageExpanded
                  ? 300
                  : (widget.list.coverImageUrl != null ? 100 : 55),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient:
                    widget.list.coverImageUrl == null
                        ? AppColors.primaryGradient
                        : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image (if exists)
                  if (widget.list.coverImageUrl != null)
                    Image.network(
                      widget.list.coverImageUrl!,
                      fit: _isImageExpanded ? BoxFit.contain : BoxFit.cover,
                      alignment:
                          _isImageExpanded
                              ? Alignment.topCenter
                              : Alignment.center,
                    ),
                  // Visibility badge and event date (left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
                        // Visibility badge
                        GestureDetector(
                          onTap: _showVisibilityDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  widget.list.isPublic
                                      ? PhosphorIcons.usersThree()
                                      : PhosphorIcons.lock(),
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.list.isPublic ? 'Public' : 'Private',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Event date badge
                        if (widget.list.hasEventDate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.list.isUpcoming
                                  ? AppColors.primary.withValues(alpha: 0.9)
                                  : Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  widget.list.isRecurring
                                      ? PhosphorIcons.arrowsClockwise()
                                      : PhosphorIcons.calendarDots(),
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getEventDateLabel(),
                                  style: AppTypography.labelMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // View image button (right) - only if cover image exists
                  if (widget.list.coverImageUrl != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleImageExpanded,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: PhosphorIcon(
                            _isImageExpanded
                                ? PhosphorIcons.arrowsInSimple()
                                : PhosphorIcons.arrowsOutSimple(),
                            size: 16,
                            color: Colors.white,
                          ),
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
                    widget.list.title,
                    style: AppTypography.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (widget.list.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.list.description!,
                      style: AppTypography.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      // Stats with pipe separators
                      Text(
                        '${widget.list.itemCount} ${widget.list.itemCount == 1 ? 'item' : 'items'}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '  |  ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${widget.list.claimedCount} committed',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '  |  ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '0 purchased',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const Spacer(),

                      // Share button
                      IconButton(
                        onPressed: widget.onShareTap,
                        icon: PhosphorIcon(PhosphorIcons.shareFat(), size: 20),
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Progress bar
                  if (widget.list.itemCount > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.list.progressPercentage,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
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
}
