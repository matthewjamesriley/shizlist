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
  final Function(bool isPublic)? onVisibilityChanged;
  final VoidCallback? onFriendsTap;
  final int friendsCount;
  final bool isCompact;

  const ListCard({
    super.key,
    required this.list,
    this.onTap,
    this.onVisibilityChanged,
    this.onFriendsTap,
    this.friendsCount = 0,
    this.isCompact = false,
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
      title:
          isCurrentlyPublic
              ? 'Make "$listTitle" private?'
              : 'Make "$listTitle" public?',
      content:
          isCurrentlyPublic
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
      return '${days}d';
    } else if (days <= 30) {
      final weeks = (days / 7).floor();
      return weeks == 1 ? '1 week' : '$weeks weeks';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final date = widget.list.nextEventDate!;
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildCompactCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Left: Gradient bar or thumbnail
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Middle: Title and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.list.title,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Visibility badge with text
                        GestureDetector(
                          onTap: _showVisibilityDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  widget.list.visibility == ListVisibility.public
                                      ? PhosphorIcons.globeSimple()
                                      : widget.list.visibility == ListVisibility.friends
                                          ? PhosphorIcons.usersThree()
                                          : PhosphorIcons.lock(),
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.list.visibility == ListVisibility.public
                                      ? 'Public'
                                      : widget.list.visibility == ListVisibility.friends
                                          ? 'Friends'
                                          : 'Private',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Event date
                        if (widget.list.hasEventDate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.list.isUpcoming
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.calendarDots(),
                                  size: 12,
                                  color: widget.list.isUpcoming
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _getEventDateLabel(),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: widget.list.isUpcoming
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${widget.list.itemCount} ${widget.list.itemCount == 1 ? 'item' : 'items'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '  |  ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.list.claimedCount} committed',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '  |  ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${widget.list.purchasedCount} purchased',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (widget.list.itemCount > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: widget.list.progressPercentage,
                                backgroundColor: AppColors.divider,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: Friends badge
              GestureDetector(
                onTap: widget.onFriendsTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.users(),
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (widget.friendsCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              widget.friendsCount > 99
                                  ? '99+'
                                  : '${widget.friendsCount}',
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with cover or gradient
            Container(
              height:
                  _isImageExpanded
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
                                  widget.list.visibility == ListVisibility.public
                                      ? PhosphorIcons.globeSimple()
                                      : widget.list.visibility == ListVisibility.friends
                                          ? PhosphorIcons.usersThree()
                                          : PhosphorIcons.lock(),
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.list.visibility == ListVisibility.public
                                      ? 'Public'
                                      : widget.list.visibility == ListVisibility.friends
                                          ? 'Friends'
                                          : 'Private',
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
                              color:
                                  widget.list.isUpcoming
                                      ? AppColors.primary.withValues(alpha: 0.9)
                                      : Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.calendarDots(),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
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
                          color: AppColors.textPrimary,
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.list.purchasedCount} purchased',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const Spacer(),

                      // Friends icon with badge
                      GestureDetector(
                        onTap: widget.onFriendsTap,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.textPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.users(),
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // Badge
                            if (widget.friendsCount > 0)
                              Positioned(
                                right: -8,
                                top: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                    minHeight: 22,
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.friendsCount > 99
                                          ? '99+'
                                          : '${widget.friendsCount}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
