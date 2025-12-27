import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/list_item.dart';
import '../services/item_service.dart';
import '../services/supabase_service.dart';
import 'app_dialog.dart';
import 'app_notification.dart';

/// Sheet for viewing a friend's item with commit/purchase options
class ViewItemSheet extends StatefulWidget {
  final ListItem item;
  final String listTitle;
  final String ownerName;
  final bool notifyOnCommit;
  final bool notifyOnPurchase;
  final VoidCallback? onActionComplete;

  const ViewItemSheet({
    super.key,
    required this.item,
    required this.listTitle,
    required this.ownerName,
    this.notifyOnCommit = true,
    this.notifyOnPurchase = true,
    this.onActionComplete,
  });

  /// Show the view item sheet
  static Future<void> show(
    BuildContext context, {
    required ListItem item,
    required String listTitle,
    required String ownerName,
    bool notifyOnCommit = true,
    bool notifyOnPurchase = true,
    VoidCallback? onActionComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useRootNavigator: true,
      builder: (context) => ViewItemSheet(
        item: item,
        listTitle: listTitle,
        ownerName: ownerName,
        notifyOnCommit: notifyOnCommit,
        notifyOnPurchase: notifyOnPurchase,
        onActionComplete: onActionComplete,
      ),
    );
  }

  @override
  State<ViewItemSheet> createState() => _ViewItemSheetState();
}

class _ViewItemSheetState extends State<ViewItemSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  bool _notifyFriends = true;
  bool _isLoading = false;
  late ListItem _item;

  String get _ownerFirstName => widget.ownerName.split(' ').first;
  bool get _isMyCommit => _item.claimedByUserId == SupabaseService.currentUserId;
  bool get _isMyPurchase => _item.purchasedByUserId == SupabaseService.currentUserId;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 2, // Start on details tab
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _commitToItem() async {
    setState(() => _isLoading = true);
    try {
      await ItemService().commitToItem(
        itemUid: _item.uid,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) {
        AppNotification.success(context, 'Committed to "${_item.name}"');
        widget.onActionComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to commit: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeCommit() async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Revoke commitment?',
      content: 'Are you sure you want to revoke your commitment to this item?',
      cancelText: 'Cancel',
      confirmText: 'Revoke',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ItemService().uncommitFromItem(_item.uid);
      if (mounted) {
        AppNotification.success(context, 'Commitment revoked');
        widget.onActionComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to revoke: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseItem() async {
    setState(() => _isLoading = true);
    try {
      await ItemService().purchaseItem(
        itemUid: _item.uid,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) {
        AppNotification.success(context, 'Marked "${_item.name}" as purchased');
        widget.onActionComplete?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to mark as purchased: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProductLink() async {
    if (_item.retailerUrl == null) return;
    final uri = Uri.parse(_item.retailerUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } else {
      if (mounted) {
        AppNotification.error(context, 'Could not open link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Cancel button and list info
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Close',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.user(),
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _ownerFirstName,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  labelStyle: AppTypography.titleMedium.copyWith(fontSize: 16),
                  tabs: const [
                    Tab(text: 'Commit'),
                    Tab(text: 'Purchased'),
                    Tab(text: 'Item details'),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCommitTab(),
                _buildPurchasedTab(),
                _buildDetailsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitTab() {
    // Check if viewing existing commitment by current user
    if (_isMyCommit) {
      return _buildExistingCommitView();
    }

    // Check if someone else has committed
    if (_item.claimedByUserId != null) {
      return _buildOtherUserCommitView();
    }

    return _buildNewCommitView();
  }

  Widget _buildNewCommitView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(AppColors.accent, Icons.card_giftcard),
          const SizedBox(height: 20),

          Text(
            'Commit to this item?',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Let others know you\'re planning to get this item.',
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Notify friends checkbox
          _buildNotifyFriendsCheckbox(),

          const SizedBox(height: 16),

          // Owner notification status
          _buildOwnerNotificationStatus(),

          const SizedBox(height: 20),

          // Note field
          _buildNoteField(),

          const SizedBox(height: 20),

          // Commit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _commitToItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Commit to item',
                          style: AppTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Link to purchased tab
          TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: Text(
              'Mark as purchased',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingCommitView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(AppColors.primary, Icons.check_circle),
          const SizedBox(height: 20),

          Text(
            'Your commitment',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re committed to getting this item.',
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          // Show note if exists
          if (_item.commitNote != null && _item.commitNote!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildNoteDisplay('Your note', _item.commitNote!, AppColors.surfaceVariant),
          ],

          const SizedBox(height: 24),

          // Revoke button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _revokeCommit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Revoke commitment',
                          style: AppTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: Text(
              'Mark as purchased',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherUserCommitView() {
    final committerName = _item.claimedByDisplayName ?? 'Someone';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(Colors.amber, Icons.check_circle),
          const SizedBox(height: 20),

          Text(
            'Committed',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'by $committerName',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.brown.shade800,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This item has already been committed to. You can still view the item details.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          if (_item.commitNote != null && _item.commitNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNoteDisplay(
              'Note from $committerName',
              _item.commitNote!,
              Colors.amber.shade50,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchasedTab() {
    if (_item.isPurchased) {
      if (_isMyPurchase) {
        return _buildMyPurchaseView();
      } else {
        return _buildOtherUserPurchaseView();
      }
    }

    return _buildNewPurchaseView();
  }

  Widget _buildNewPurchaseView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(AppColors.primary, Icons.shopping_bag),
          const SizedBox(height: 20),

          Text(
            'Mark as purchased?',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Let others know you\'ve purchased this item.',
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          _buildNoteField(),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _purchaseItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Mark as purchased',
                          style: AppTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPurchaseView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(AppColors.primary, Icons.shopping_bag),
          const SizedBox(height: 20),

          Text(
            'You purchased this',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This item has been marked as purchased.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          if (_item.purchaseNote != null && _item.purchaseNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNoteDisplay(
              'Your note',
              _item.purchaseNote!,
              AppColors.primary.withValues(alpha: 0.05),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherUserPurchaseView() {
    final purchaserName = _item.purchasedByDisplayName ?? 'Someone';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildItemThumbnail(AppColors.primary, Icons.shopping_bag),
          const SizedBox(height: 20),

          Text(
            'Purchased',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'by $purchaserName',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This item has already been purchased.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          if (_item.purchaseNote != null && _item.purchaseNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNoteDisplay(
              'Note from $purchaserName',
              _item.purchaseNote!,
              AppColors.primary.withValues(alpha: 0.05),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          if (_item.thumbnailUrl != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _item.mainImageUrl ?? _item.thumbnailUrl!,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Item name
          Text(
            _item.name,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // From list badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'From: ${widget.listTitle}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (_item.description != null) ...[
            const SizedBox(height: 16),
            Text(
              _item.description!,
              style: AppTypography.bodyLarge,
            ),
          ],

          const SizedBox(height: 20),

          // Price and category row
          Row(
            children: [
              if (_item.price != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _item.formattedPrice,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      _item.category.icon,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _item.category.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Retailer link
          if (_item.retailerUrl != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openProductLink,
                icon: PhosphorIcon(PhosphorIcons.arrowSquareOut(), size: 18),
                label: const Text('View product'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemThumbnail(Color color, IconData icon) {
    if (_item.thumbnailUrl != null) {
      return Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: ClipOval(
          child: Image.network(
            _item.thumbnailUrl!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  Widget _buildNotifyFriendsCheckbox() {
    return Center(
      child: InkWell(
        onTap: () => setState(() => _notifyFriends = !_notifyFriends),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.3,
                child: Checkbox(
                  value: _notifyFriends,
                  onChanged: (value) => setState(() => _notifyFriends = value ?? false),
                  activeColor: AppColors.accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Alert friends connected to this list',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerNotificationStatus() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              widget.notifyOnCommit
                  ? PhosphorIcons.bellRinging()
                  : PhosphorIcons.bellSlash(),
              size: 22,
              color: widget.notifyOnCommit ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.notifyOnCommit
                    ? '$_ownerFirstName will be notified automatically'
                    : '$_ownerFirstName has chosen not to be notified.',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.black,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        hintText: 'Add a note (optional)',
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.textSecondary,
          fontSize: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: AppTypography.bodyLarge.copyWith(fontSize: 16),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildNoteDisplay(String title, String note, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

