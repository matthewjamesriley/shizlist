import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/friend.dart';
import '../../../models/models.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/friend_service.dart';
import '../../../services/item_service.dart';
import '../../../services/list_service.dart';
import '../../../services/list_share_service.dart';
import '../../../services/lists_notifier.dart';
import '../../../services/notification_service.dart';
import '../../../models/app_notification.dart';
import '../../../widgets/add_item_sheet.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/bottom_sheet_header.dart';
import '../../../widgets/edit_item_sheet.dart';
import '../../../widgets/item_card.dart';
import '../../../widgets/fading_image_carousel.dart';
import '../../../services/supabase_service.dart';
import '../../notifications/screens/notifications_screen.dart';

/// List detail screen showing items in a wish list
class ListDetailScreen extends StatefulWidget {
  final String listUid;

  const ListDetailScreen({super.key, required this.listUid});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen>
    with SingleTickerProviderStateMixin {
  late WishList _list;
  List<ListItem> _items = [];
  bool _isLoading = true;
  String _sortOption = 'newest';
  ItemCategory? _selectedCategoryFilter; // null = All

  // Owner info for friend's lists
  UserProfile? _ownerProfile;

  // Check if current user is the list owner
  bool get _isOwner => _list.ownerId == SupabaseService.currentUserId;

  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedItemUids = {};

  // Notifications
  final NotificationService _notificationService = NotificationService();
  int _unreadNotifications = 0;

  // Slide-in notification toast
  AppNotificationModel? _toastNotification;
  bool _showToast = false;

  // Priority animation overlay
  bool _showPriorityAnimation = false;
  ItemPriority? _animatedPriority;
  int _priorityAnimationKey = 0; // Key to force animation restart
  Timer? _priorityAnimationTimer;

  // Hide purchased items toggle
  bool _hidePurchased = false;

  // Get filtered and sorted items
  List<ListItem> get _filteredItems {
    List<ListItem> items;

    // Filter by category
    if (_selectedCategoryFilter == null) {
      items = List.from(_items);
    } else {
      items =
          _items
              .where((item) => item.category == _selectedCategoryFilter)
              .toList();
    }

    // Filter out purchased items if toggle is on
    if (_hidePurchased) {
      items = items.where((item) => !item.isPurchased).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case 'priority_high':
        items.sort(
          (a, b) =>
              _priorityValue(b.priority).compareTo(_priorityValue(a.priority)),
        );
        break;
      case 'priority_low':
        items.sort(
          (a, b) =>
              _priorityValue(a.priority).compareTo(_priorityValue(b.priority)),
        );
        break;
      case 'price_high':
        items.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case 'price_low':
        items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case 'oldest':
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'alpha_az':
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'alpha_za':
        items.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'newest':
      default:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return items;
  }

  // Convert priority enum to sortable value (higher = more important)
  int _priorityValue(ItemPriority priority) {
    switch (priority) {
      case ItemPriority.high:
        return 3;
      case ItemPriority.medium:
        return 2;
      case ItemPriority.low:
        return 1;
      case ItemPriority.none:
        return 0;
    }
  }

  // Controls FAB visibility (starts hidden to avoid spin animation)
  bool _showButtons = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadList();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    _notificationService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() => _unreadNotifications = count);
      }
    });
    _notificationService.newNotificationStream.listen((notification) {
      if (mounted) {
        _showNotificationToast(notification);
      }
    });
    if (mounted) {
      setState(() => _unreadNotifications = _notificationService.unreadCount);
    }
  }

  void _showNotificationToast(AppNotificationModel notification) {
    // Play alert sound
    final player = AudioPlayer();
    player.play(AssetSource('sounds/alert.mp3'));

    // First add the widget to the tree off-screen
    setState(() {
      _toastNotification = notification;
      _showToast = false;
    });

    // Then animate it in after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showToast = true);
      }
    });

    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _toastNotification?.uid == notification.uid) {
        setState(() => _showToast = false);
        // Clear notification after animation completes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _toastNotification?.uid == notification.uid) {
            setState(() => _toastNotification = null);
          }
        });
      }
    });
  }

  void _dismissToast() {
    setState(() => _showToast = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _toastNotification = null);
      }
    });
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _priorityAnimationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadList() async {
    try {
      // Fetch the actual list from Supabase
      final list = await ListService().getListByUid(widget.listUid);

      if (list == null) {
        if (mounted) {
          context.go('/lists');
        }
        return;
      }

      // Load items for this list
      final items = await ItemService().getListItems(list.id);

      // Show content immediately
      setState(() {
        _list = list;
        _items = items;
        _isLoading = false;
      });

      // Start fade-in animation after content loads
      _fadeController.forward();

      // Show buttons after a brief delay to avoid spin animation (only for owner)
      if (list.ownerId == SupabaseService.currentUserId) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() => _showButtons = true);
          }
        });
      }

      // If viewing a friend's list, fetch their profile in the background
      if (list.ownerId != SupabaseService.currentUserId) {
        _loadOwnerProfileInBackground(list.ownerId);
      }
    } catch (e) {
      debugPrint('Error loading list: $e');
      if (mounted) {
        context.go('/lists');
      }
    }
  }

  /// Load owner profile in background without blocking UI
  Future<void> _loadOwnerProfileInBackground(String ownerId) async {
    try {
      final profileData =
          await SupabaseService.client
              .from('users')
              .select()
              .eq('uid', ownerId)
              .maybeSingle();
      if (profileData != null && mounted) {
        setState(() {
          _ownerProfile = UserProfile.fromJson(profileData);
        });
      }
    } catch (e) {
      debugPrint('Error fetching owner profile: $e');
    }
  }

  Future<void> _refreshItems() async {
    try {
      final items = await ItemService().getListItems(_list.id);
      setState(() {
        _items = items;
      });
    } catch (e) {
      debugPrint('Error refreshing items: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get item images for carousel (when no cover image is set) - prefer main images over thumbnails
    final itemImages = _items
        .where((item) => item.mainImageUrl != null || item.thumbnailUrl != null)
        .take(5)
        .map((item) => item.mainImageUrl ?? item.thumbnailUrl!)
        .toList();
    final hasCarouselImages = _list.coverImageUrl == null && itemImages.isNotEmpty;

    // Use taller header on iPad/tablets when there's a cover image or carousel
    final isTablet = MediaQuery.of(context).size.width > 600;
    final baseToolbarHeight = _list.description != null ? 70.0 : kToolbarHeight;
    final hasImage = _list.coverImageUrl != null || hasCarouselImages;
    final toolbarHeight =
        hasImage && isTablet ? 140.0 : baseToolbarHeight;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            _list.coverImageUrl != null
                ? Colors.transparent
                : AppColors.primary,
        foregroundColor: Colors.white,
        flexibleSpace:
            _list.coverImageUrl != null
                ? Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Solid color base (shows while loading)
                    Container(color: AppColors.primary),
                    // Fading image on top - centered
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Image.network(
                              _list.coverImageUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          );
                        },
                      ),
                    ),
                    // Dark overlay
                    Container(color: Colors.black.withValues(alpha: 0.5)),
                  ],
                )
                : hasCarouselImages
                ? Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Solid color base
                    Container(color: AppColors.primary),
                    // Fading carousel of item images with pan effect
                    Positioned.fill(
                      child: FadingImageCarousel(
                        imageUrls: itemImages,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        displayDuration: const Duration(seconds: 8),
                        fadeDuration: const Duration(milliseconds: 1200),
                        enablePan: true,
                        panScale: 1.15,
                      ),
                    ),
                    // Dark overlay
                    Container(color: Colors.black.withValues(alpha: 0.5)),
                  ],
                )
                : null,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        toolbarHeight: toolbarHeight,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_list.title, style: const TextStyle(color: Colors.white)),
            if (_list.description != null) ...[
              const SizedBox(height: 4),
              Text(
                _list.description!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          // Notifications bell icon
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _openNotifications,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.bell(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: -4,
                      top: -4,
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
                            _unreadNotifications > 99
                                ? '99+'
                                : '$_unreadNotifications',
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
          ),
          if (_isOwner)
            PopupMenuButton<String>(
              iconColor: Colors.white,
              onSelected: _handleMenuAction,
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.pencilSimple(),
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Edit list',
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'friends',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.users(),
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Manage friends',
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'toggle_purchased',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.shoppingCart(),
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hide purchased',
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Switch(
                            value: _hidePurchased,
                            onChanged: (value) {
                              setState(() => _hidePurchased = value);
                              Navigator.pop(context);
                            },
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.trash(),
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete list',
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 15,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
            )
          else if (_ownerProfile != null)
            // Show owner info for friend's lists
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ownerProfile!.nameOrEmail.split(' ').first,
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_ownerProfile!.avatarUrl != null)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(_ownerProfile!.avatarUrl!),
                      backgroundColor: Colors.white24,
                    )
                  else
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Text(
                        _ownerProfile!.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Info row
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.white,
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.66, 1.0],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - public/private, item count, and event date
                      Expanded(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  _list.visibility == ListVisibility.public
                                      ? PhosphorIcons.globeSimple()
                                      : _list.visibility ==
                                          ListVisibility.friends
                                      ? PhosphorIcons.usersThree()
                                      : PhosphorIcons.lock(),
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _list.visibility == ListVisibility.public
                                      ? 'Public'
                                      : _list.visibility ==
                                          ListVisibility.friends
                                      ? 'Friends'
                                      : 'Private',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            if (_list.hasEventDate)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PhosphorIcon(
                                    PhosphorIcons.calendarDots(),
                                    size: 20,
                                    color:
                                        _list.isUpcoming
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getEventDateDisplay(),
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontSize: 15,
                                      color:
                                          _list.isUpcoming
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Right side - Sort dropdown
                      Row(
                        children: [
                          // Sort dropdown
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() => _sortOption = value);
                            },
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getSortLabel(_sortOption),
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PhosphorIcon(
                                  PhosphorIcons.caretDown(),
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ],
                            ),
                            itemBuilder:
                                (context) => [
                                  _buildSortMenuItem(
                                    'priority_high',
                                    'Priority: High to Low',
                                  ),
                                  _buildSortMenuItem(
                                    'priority_low',
                                    'Priority: Low to High',
                                  ),
                                  const PopupMenuDivider(),
                                  _buildSortMenuItem(
                                    'price_high',
                                    'Price: High to Low',
                                  ),
                                  _buildSortMenuItem(
                                    'price_low',
                                    'Price: Low to High',
                                  ),
                                  const PopupMenuDivider(),
                                  _buildSortMenuItem('newest', 'Newest First'),
                                  _buildSortMenuItem('oldest', 'Oldest First'),
                                  const PopupMenuDivider(),
                                  _buildSortMenuItem(
                                    'alpha_az',
                                    'Name: A to Z',
                                  ),
                                  _buildSortMenuItem(
                                    'alpha_za',
                                    'Name: Z to A',
                                  ),
                                ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(
                          'All',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        selected: _selectedCategoryFilter == null,
                        onSelected: (_) {
                          setState(() => _selectedCategoryFilter = null);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.white,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        side: BorderSide(
                          color:
                              _selectedCategoryFilter == null
                                  ? AppColors.primary
                                  : AppColors.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ...ItemCategory.values.map((category) {
                        final isSelected = _selectedCategoryFilter == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: FilterChip(
                            label: Text(
                              category.displayName,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(
                                () => _selectedCategoryFilter = category,
                              );
                            },
                            avatar: Icon(
                              category.icon,
                              size: 18,
                              color: category.color,
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: Colors.white,
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            labelPadding: const EdgeInsets.only(
                              left: 1,
                              right: 7,
                            ),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Items list
                Expanded(
                  child:
                      _items.isEmpty
                          ? _buildEmptyState()
                          : _filteredItems.isEmpty
                          ? _buildNoFilterResultsState()
                          : RefreshIndicator(
                            onRefresh: _loadList,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                final isSelected = _selectedItemUids.contains(
                                  item.uid,
                                );

                                if (_isMultiSelectMode) {
                                  return _buildSelectableItem(
                                    item,
                                    isSelected,
                                    index,
                                  );
                                }

                                // Calculate position for grouped card style
                                final itemCount = _filteredItems.length;
                                ItemPosition position;
                                if (itemCount == 1) {
                                  position = ItemPosition.only;
                                } else if (index == 0) {
                                  position = ItemPosition.first;
                                } else if (index == itemCount - 1) {
                                  position = ItemPosition.last;
                                } else {
                                  position = ItemPosition.middle;
                                }

                                return ItemCard(
                                  item: item,
                                  isOwner: _isOwner,
                                  currentUserId: SupabaseService.currentUserId,
                                  notifyOnCommit: _list.notifyOnCommit,
                                  notifyOnPurchase: _list.notifyOnPurchase,
                                  onTap: () => _openItemDetail(item),
                                  onCommitTap: () => _commitItem(item),
                                  onCommitStatusTap:
                                      _isOwner
                                          ? () => _showOwnerStatusInfo(
                                            item,
                                            showPurchase: false,
                                          )
                                          : () => _openCommitStatus(
                                            item,
                                            initialTab: 0,
                                          ),
                                  onPurchaseStatusTap:
                                      _isOwner
                                          ? () => _showOwnerStatusInfo(
                                            item,
                                            showPurchase: true,
                                          )
                                          : () => _openCommitStatus(
                                            item,
                                            initialTab: 1,
                                          ),
                                  onLinkTap:
                                      item.retailerUrl != null
                                          ? () => _openProductLink(
                                            item.retailerUrl!,
                                          )
                                          : null,
                                  onPriorityTap:
                                      _isOwner
                                          ? () => _cyclePriority(item)
                                          : null,
                                  position: position,
                                );
                              },
                            ),
                          ),
                ),
              ],
            ),
          ),

          // Floating buttons (positioned at bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset:
                  (_showButtons && !_isMultiSelectMode)
                      ? Offset.zero
                      : const Offset(0, 0.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_showButtons && !_isMultiSelectMode) ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showButtons || _isMultiSelectMode,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Multi select button (left)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                              side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap:
                                  () => setState(() {
                                    _isMultiSelectMode = true;
                                    _selectedItemUids.clear();
                                  }),
                              borderRadius: BorderRadius.circular(32),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                child: Text(
                                  'Multi select (${_items.length} ${_items.length == 1 ? 'item' : 'items'})',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.black,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Add Item button (right) - Orange
                      Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(),
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        child: InkWell(
                          onTap: () => _addItem(),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: PhosphorIcon(
                              PhosphorIcons.plus(),
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Slide-in notification toast
          if (_toastNotification != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: 16,
              right: _showToast ? 12 : -350,
              child: GestureDetector(
                onTap: () {
                  _dismissToast();
                  _openNotifications();
                },
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 0) {
                    _dismissToast();
                  }
                },
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.bell(PhosphorIconsStyle.fill),
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _toastNotification!.title,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_toastNotification!.message != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _toastNotification!.message!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PhosphorIcon(
                          PhosphorIcons.caretRight(),
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Priority change animation overlay
          if (_showPriorityAnimation && _animatedPriority != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_priorityAnimationKey),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      // Icon: starts at 0ms, scale and fade
                      final iconScale = 0.5 + (value * 0.7);
                      final iconOpacity = (value < 0.7
                              ? 1.0
                              : 1.0 - ((value - 0.7) / 0.3))
                          .clamp(0.0, 1.0);

                      // Circle 1: starts at 200ms (0.17 of 1200ms)
                      const circle1Start = 0.17;
                      final circle1Opacity =
                          value < circle1Start
                              ? 0.0
                              : value < circle1Start + 0.1
                              ? ((value - circle1Start) / 0.1).clamp(0.0, 1.0)
                              : value < 0.7
                              ? 1.0
                              : (1.0 - ((value - 0.7) / 0.3)).clamp(0.0, 1.0);

                      // Circle 2: starts at 400ms (0.33 of 1200ms)
                      const circle2Start = 0.33;
                      final circle2Opacity =
                          value < circle2Start
                              ? 0.0
                              : value < circle2Start + 0.1
                              ? ((value - circle2Start) / 0.1).clamp(0.0, 1.0)
                              : value < 0.75
                              ? 1.0
                              : (1.0 - ((value - 0.75) / 0.25)).clamp(0.0, 1.0);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circle 2 (outer, delayed most)
                          Opacity(
                            opacity: circle2Opacity * 0.1,
                            child: Transform.scale(
                              scale: iconScale * 1.5,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: _animatedPriority!.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          // Circle 1 (inner, delayed)
                          Opacity(
                            opacity: circle1Opacity * 0.15,
                            child: Transform.scale(
                              scale: iconScale,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: _animatedPriority!.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          // Icon (immediate)
                          Opacity(
                            opacity: iconOpacity,
                            child: Transform.scale(
                              scale: iconScale,
                              child: PhosphorIcon(
                                _animatedPriority!.icon,
                                size: 64,
                                color: _animatedPriority!.color,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: _isMultiSelectMode ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isMultiSelectMode ? 1.0 : 0.0,
          child:
              _isMultiSelectMode
                  ? _buildMultiSelectBar()
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required PhosphorIconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected ? AppColors.claimedBackground : Colors.grey.shade100,
        ),
        child: Column(
          children: [
            PhosphorIcon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
          ),
          child: Row(
            children: [
              // Selected count
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${_selectedItemUids.length} selected',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              // Set Priority button
              if (_selectedItemUids.isNotEmpty)
                IconButton(
                  onPressed: _showPrioritySheet,
                  icon: PhosphorIcon(PhosphorIcons.star(), color: Colors.white),
                  tooltip: 'Set Priority',
                ),
              // Delete button
              if (_selectedItemUids.isNotEmpty)
                IconButton(
                  onPressed: _deleteSelectedItems,
                  icon: PhosphorIcon(
                    PhosphorIcons.trash(),
                    color: AppColors.error,
                  ),
                  tooltip: 'Delete',
                ),
              // Dotted separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    6,
                    (index) => Container(
                      width: 2,
                      height: 2,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              // Cancel/Close button
              IconButton(
                onPressed:
                    () => setState(() {
                      _isMultiSelectMode = false;
                      _selectedItemUids.clear();
                    }),
                icon: PhosphorIcon(
                  PhosphorIcons.xCircle(),
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 28,
                ),
                tooltip: 'Cancel',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSortLabel(String option) {
    switch (option) {
      case 'priority_high':
        return 'Priority High';
      case 'priority_low':
        return 'Priority Low';
      case 'price_high':
        return 'Price High';
      case 'price_low':
        return 'Price Low';
      case 'newest':
        return 'Newest';
      case 'oldest':
        return 'Oldest';
      case 'alpha_az':
        return 'A-Z';
      case 'alpha_za':
        return 'Z-A';
      default:
        return 'Sort';
    }
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    final isSelected = _sortOption == value;
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (isSelected)
            PhosphorIcon(
              PhosphorIcons.check(),
              size: 20,
              color: AppColors.primary,
            )
          else
            const SizedBox(width: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 15,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
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
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text('No Items Yet', style: AppTypography.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add items to your list using the + button',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedCategoryFilter?.icon ?? Icons.filter_list,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedCategoryFilter?.displayName ?? ''} Items',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different category or tap "All" to see all items',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _selectedCategoryFilter = null),
              child: const Text('Show All Items'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _showEditListSheet();
        break;
      case 'friends':
        _showManageFriendsSheet();
        break;
      case 'toggle_purchased':
        setState(() => _hidePurchased = !_hidePurchased);
        break;
      case 'delete':
        _confirmDeleteList();
        break;
    }
  }

  void _showManageFriendsSheet() async {
    final friendService = FriendService();
    final listShareService = ListShareService();
    final friends = await friendService.getFriends();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useRootNavigator: true,
      builder:
          (context) => _ManageFriendsSheet(
            list: _list,
            friends: friends,
            listShareService: listShareService,
            onComplete: () {
              // Refresh the list to show updated friend count if needed
            },
          ),
    );
  }

  void _showEditListSheet() {
    final titleController = TextEditingController(text: _list.title);
    final descriptionController = TextEditingController(
      text: _list.description ?? '',
    );
    var visibility = _list.visibility;
    var isLoading = false;

    // Notification preferences
    var notifyOnCommit = _list.notifyOnCommit;
    var notifyOnPurchase = _list.notifyOnPurchase;

    // Cover image state
    File? selectedImage;
    String? uploadedImageUrl = _list.coverImageUrl;
    bool isUploadingImage = false;
    double uploadProgress = 0;
    String uploadStatus = '';

    // Event date state
    DateTime? eventDate = _list.eventDate;
    bool isRecurring = _list.isRecurring;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      useRootNavigator: true,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> pickImage(ImageSource source) async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1200,
                  maxHeight: 1200,
                );

                if (picked == null) return;

                final file = File(picked.path);
                setSheetState(() {
                  selectedImage = file;
                  uploadedImageUrl = null;
                });

                // Start upload
                setSheetState(() {
                  isUploadingImage = true;
                  uploadProgress = 0;
                  uploadStatus = 'Processing image...';
                });

                try {
                  final result = await ImageUploadService().processAndUpload(
                    file,
                    onProgress: (progress, status) {
                      setSheetState(() {
                        uploadProgress = progress;
                        uploadStatus = status;
                      });
                    },
                  );

                  setSheetState(() {
                    uploadedImageUrl = result?.mainImageUrl;
                    isUploadingImage = false;
                  });
                } catch (e) {
                  setSheetState(() {
                    isUploadingImage = false;
                    selectedImage = null;
                  });
                  if (mounted) {
                    AppNotification.error(context, 'Failed to upload image');
                  }
                }
              }

              void removeImage() {
                setSheetState(() {
                  selectedImage = null;
                  uploadedImageUrl = null;
                });
              }

              Future<void> handleSave() async {
                if (titleController.text.trim().isEmpty) return;

                setSheetState(() => isLoading = true);

                try {
                  final descText = descriptionController.text.trim();
                  final updatedList = await ListService().updateList(
                    uid: _list.uid,
                    title: titleController.text.trim(),
                    description: descText.isEmpty ? null : descText,
                    clearDescription: descText.isEmpty,
                    coverImageUrl: uploadedImageUrl,
                    clearCoverImage:
                        uploadedImageUrl == null && _list.coverImageUrl != null,
                    visibility: visibility,
                    eventDate: eventDate,
                    clearEventDate:
                        eventDate == null && _list.eventDate != null,
                    isRecurring: isRecurring,
                    notifyOnCommit: notifyOnCommit,
                    notifyOnPurchase: notifyOnPurchase,
                  );

                  setState(() {
                    _list = updatedList;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    AppNotification.success(context, 'List updated');
                  }
                } catch (e) {
                  setSheetState(() => isLoading = false);
                  if (mounted) {
                    AppNotification.show(
                      context,
                      message: 'Failed to update: $e',
                      icon: PhosphorIcons.warning(),
                      backgroundColor: AppColors.error,
                    );
                  }
                }
              }

              Widget buildCoverImagePicker() {
                if (isUploadingImage) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: uploadProgress,
                            backgroundColor: AppColors.divider,
                            color: AppColors.primary,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          uploadStatus,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (selectedImage != null || uploadedImageUrl != null) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Show full-screen preview
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              opaque: false,
                              barrierColor: Colors.black87,
                              pageBuilder: (
                                ctx,
                                animation,
                                secondaryAnimation,
                              ) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: Scaffold(
                                    backgroundColor: Colors.transparent,
                                    body: GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Container(color: Colors.transparent),
                                          Center(
                                            child: InteractiveViewer(
                                              minScale: 0.5,
                                              maxScale: 4.0,
                                              child:
                                                  selectedImage != null
                                                      ? Image.file(
                                                        selectedImage!,
                                                      )
                                                      : Image.network(
                                                        uploadedImageUrl!,
                                                      ),
                                            ),
                                          ),
                                          Positioned(
                                            top:
                                                MediaQuery.of(ctx).padding.top +
                                                16,
                                            right: 16,
                                            child: GestureDetector(
                                              onTap: () => Navigator.pop(ctx),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              selectedImage != null
                                  ? Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                  : Image.network(
                                    uploadedImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => pickImage(ImageSource.gallery),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.image(),
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gallery',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => pickImage(ImageSource.camera),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.camera(),
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Camera',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Header
                    BottomSheetHeader(
                      title: 'Edit list',
                      confirmText: 'Save',
                      onCancel: () => Navigator.pop(context),
                      onConfirm: handleSave,
                      isLoading: isLoading,
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // List name
                            Text('List name', style: AppTypography.titleMedium),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: titleController,
                              style: AppTypography.titleMedium,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. Birthday, Wedding, Christmas etc...',
                                hintStyle: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Description
                            Text(
                              'Description (optional)',
                              style: AppTypography.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: descriptionController,
                              style: AppTypography.titleMedium,
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 1,
                              decoration: InputDecoration(
                                hintText: 'A short description...',
                                hintStyle: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Cover image
                            Text(
                              'Cover image (optional)',
                              style: AppTypography.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            buildCoverImagePicker(),
                            const SizedBox(height: 20),

                            // Event date & Recurring
                            Text(
                              'Event date (optional)',
                              style: AppTypography.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Date picker
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            eventDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                        helpText: 'Select event date',
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                    primary: AppColors.primary,
                                                    onPrimary: Colors.white,
                                                    surface: AppColors.surface,
                                                    onSurface:
                                                        AppColors.textPrimary,
                                                  ),
                                              textTheme: Theme.of(
                                                context,
                                              ).textTheme.copyWith(
                                                labelSmall: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                headlineMedium: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              textButtonTheme:
                                                  TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setSheetState(() => eventDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.divider,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.calendarDots(),
                                            size: 20,
                                            color:
                                                eventDate != null
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              eventDate != null
                                                  ? _formatEventDateShort(
                                                    eventDate!,
                                                  )
                                                  : 'Select date',
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                    color:
                                                        eventDate != null
                                                            ? AppColors
                                                                .textPrimary
                                                            : AppColors
                                                                .textSecondary,
                                                  ),
                                            ),
                                          ),
                                          if (eventDate != null)
                                            GestureDetector(
                                              onTap:
                                                  () => setSheetState(() {
                                                    eventDate = null;
                                                    isRecurring = false;
                                                  }),
                                              child: PhosphorIcon(
                                                PhosphorIcons.xCircle(),
                                                size: 20,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Recurring toggle (only show if date is set)
                                if (eventDate != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap:
                                        () => setSheetState(
                                          () => isRecurring = !isRecurring,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              isRecurring
                                                  ? AppColors.primary
                                                  : AppColors.divider,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color:
                                            isRecurring
                                                ? AppColors.primary.withOpacity(
                                                  0.05,
                                                )
                                                : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.arrowsClockwise(),
                                            size: 20,
                                            color:
                                                isRecurring
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Yearly',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  color:
                                                      isRecurring
                                                          ? AppColors.primary
                                                          : AppColors
                                                              .textPrimary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Visibility
                            Text(
                              'Visibility',
                              style: AppTypography.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildVisibilityOption(
                                    icon: PhosphorIcons.globeSimple(),
                                    title: 'Public',
                                    subtitle: 'Anyone',
                                    isSelected:
                                        visibility == ListVisibility.public,
                                    onTap:
                                        () => setSheetState(
                                          () =>
                                              visibility =
                                                  ListVisibility.public,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildVisibilityOption(
                                    icon: PhosphorIcons.usersThree(),
                                    title: 'Friends',
                                    subtitle: 'Connected',
                                    isSelected:
                                        visibility == ListVisibility.friends,
                                    onTap:
                                        () => setSheetState(
                                          () =>
                                              visibility =
                                                  ListVisibility.friends,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildVisibilityOption(
                                    icon: PhosphorIcons.lock(),
                                    title: 'Private',
                                    subtitle: 'Only you',
                                    isSelected:
                                        visibility == ListVisibility.private,
                                    onTap:
                                        () => setSheetState(
                                          () =>
                                              visibility =
                                                  ListVisibility.private,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Notification preferences
                            Builder(
                              builder: (context) {
                                final isPrivate =
                                    visibility == ListVisibility.private;
                                final commitChecked =
                                    !isPrivate && notifyOnCommit;
                                final purchaseChecked =
                                    !isPrivate && notifyOnPurchase;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notify me when my friends...',
                                      style: AppTypography.titleMedium.copyWith(
                                        color:
                                            isPrivate
                                                ? AppColors.textSecondary
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap:
                                                isPrivate
                                                    ? null
                                                    : () => setSheetState(
                                                      () =>
                                                          notifyOnCommit =
                                                              !notifyOnCommit,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          commitChecked
                                                              ? AppColors
                                                                  .primary
                                                              : Colors
                                                                  .transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            isPrivate
                                                                ? AppColors
                                                                    .border
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    )
                                                                : (commitChecked
                                                                    ? AppColors
                                                                        .primary
                                                                    : AppColors
                                                                        .border),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child:
                                                        commitChecked
                                                            ? PhosphorIcon(
                                                              PhosphorIcons.check(
                                                                PhosphorIconsStyle
                                                                    .bold,
                                                              ),
                                                              size: 16,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                            : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Flexible(
                                                    child: Text(
                                                      'Commit to purchase',
                                                      style: AppTypography
                                                          .bodyMedium
                                                          .copyWith(
                                                            color:
                                                                isPrivate
                                                                    ? AppColors
                                                                        .textSecondary
                                                                    : null,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap:
                                                isPrivate
                                                    ? null
                                                    : () => setSheetState(
                                                      () =>
                                                          notifyOnPurchase =
                                                              !notifyOnPurchase,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          purchaseChecked
                                                              ? AppColors
                                                                  .primary
                                                              : Colors
                                                                  .transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            isPrivate
                                                                ? AppColors
                                                                    .border
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    )
                                                                : (purchaseChecked
                                                                    ? AppColors
                                                                        .primary
                                                                    : AppColors
                                                                        .border),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child:
                                                        purchaseChecked
                                                            ? PhosphorIcon(
                                                              PhosphorIcons.check(
                                                                PhosphorIconsStyle
                                                                    .bold,
                                                              ),
                                                              size: 16,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                            : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Flexible(
                                                    child: Text(
                                                      'Mark as purchased',
                                                      style: AppTypography
                                                          .bodyMedium
                                                          .copyWith(
                                                            color:
                                                                isPrivate
                                                                    ? AppColors
                                                                        .textSecondary
                                                                    : null,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  String _formatEventDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatEventDateShort(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getEventDateDisplay() {
    if (!_list.hasEventDate) return '';

    final days = _list.daysUntilEvent;
    if (days == null) return '';

    if (days == 0) {
      return 'Today!';
    } else if (days == 1) {
      return 'Tomorrow';
    } else if (days < 0) {
      return _list.isRecurring ? '${-days}d ago' : 'Passed';
    } else if (days <= 7) {
      return '$days days';
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
      final date = _list.nextEventDate!;
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  void _confirmDeleteList() async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete "${_list.title}"?',
      content:
          'Are you sure you want to delete this list? This action can be undone. All items will be deleted also.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ListService().deleteList(_list.uid);
        // Notify the lists screen to remove this list from UI
        ListsNotifier().notifyListDeleted(_list.uid);
        if (mounted) {
          AppNotification.success(context, 'Deleted "${_list.title}"');
          context.pop();
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

  void _openItemDetail(ListItem item) {
    if (_isOwner) {
      _showEditItemSheet(item);
    } else {
      // For friend's lists, open the commit sheet on the Item details tab
      _showItemDetailsSheet(item);
    }
  }

  Future<void> _cyclePriority(ListItem item) async {
    // Cycle through priorities: none -> low -> medium -> high -> none
    final priorities = [
      ItemPriority.none,
      ItemPriority.low,
      ItemPriority.medium,
      ItemPriority.high,
    ];

    final currentIndex = priorities.indexOf(item.priority);
    final nextIndex = (currentIndex + 1) % priorities.length;
    final nextPriority = priorities[nextIndex];

    // Cancel any existing animation timer
    _priorityAnimationTimer?.cancel();

    // Show the animation (increment key to restart animation)
    setState(() {
      _animatedPriority = nextPriority;
      _showPriorityAnimation = true;
      _priorityAnimationKey++;
    });

    // Haptic feedback triplet matching animation timing (0ms, 200ms, 400ms)
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticFeedback.lightImpact();
    });

    // Play sound effect based on priority (don't await - let it play in background)
    if (nextPriority != ItemPriority.none) {
      final player = AudioPlayer();
      player.setVolume(0.6); // Reduce volume by 40%
      final soundFile = switch (nextPriority) {
        ItemPriority.low => 'sounds/trill-1.m4a',
        ItemPriority.medium => 'sounds/trill-2.m4a',
        ItemPriority.high => 'sounds/trill-3.m4a',
        ItemPriority.none => '', // Won't reach here
      };
      player.play(AssetSource(soundFile));
    }

    // Auto-hide after animation
    _priorityAnimationTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _showPriorityAnimation = false);
      }
    });

    // Update local state immediately (preserve commit/purchase data)
    setState(() {
      final index = _items.indexWhere((i) => i.uid == item.uid);
      if (index != -1) {
        _items[index] = item.copyWith(priority: nextPriority);
      }
    });

    try {
      await ItemService().updateItem(uid: item.uid, priority: nextPriority);
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to update priority');
      }
    }
  }

  void _showItemDetailsSheet(ListItem item) async {
    final ownerName = _ownerProfile?.nameOrEmail ?? 'list owner';
    final isMyCommit = item.claimedByUserId == SupabaseService.currentUserId;

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder:
          (context) => _CommitSheet(
            itemName: item.name,
            ownerName: ownerName,
            thumbnailUrl: item.thumbnailUrl,
            description: item.description,
            price: item.formattedPrice,
            retailerUrl: item.retailerUrl,
            category: item.category.displayName,
            priority: item.priority.displayName,
            initialTab: 2, // Item details tab
            ownerWantsNotification: _list.notifyOnCommit,
            item: item,
            isMyCommit: isMyCommit,
          ),
    );

    // Handle actions from the sheet
    if (result != null && mounted) {
      final action = result['action'] as String;
      final note = result['note'] as String?;

      if (action == 'commit') {
        try {
          await ItemService().commitToItem(itemUid: item.uid, note: note);
          if (mounted) {
            AppNotification.success(context, 'Committed to "${item.name}"');
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to commit: $e');
          }
        }
      } else if (action == 'revoke') {
        try {
          await ItemService().uncommitFromItem(item.uid);
          if (mounted) {
            AppNotification.success(context, 'Commitment revoked');
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to revoke: $e');
          }
        }
      } else if (action == 'purchased') {
        try {
          await ItemService().purchaseItem(itemUid: item.uid, note: note);
          if (mounted) {
            AppNotification.success(
              context,
              'Marked "${item.name}" as purchased',
            );
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to mark as purchased: $e');
          }
        }
      }
    }
  }

  void _openProductLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } else {
      if (mounted) {
        AppNotification.error(context, 'Could not open link');
      }
    }
  }

  void _showEditItemSheet(ListItem item) {
    EditItemSheet.show(
      context,
      item: item,
      listUid: widget.listUid,
      onSaved: () {
        _refreshItems();
        AppNotification.success(context, 'Item updated');
      },
      onDeleted: () => _confirmDeleteItem(item),
      onListCoverChanged: _loadList,
    );
  }

  Future<void> _confirmDeleteItem(ListItem item) async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete item?',
      content: 'Are you sure you want to delete "${item.name}"?',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await ItemService().deleteItem(item.uid);
        _refreshItems();
        ListsNotifier().notifyItemCountChanged();
        AppNotification.success(context, 'Item deleted');
      } catch (e) {
        AppNotification.error(context, 'Failed to delete item');
      }
    }
  }

  void _commitItem(ListItem item) async {
    final ownerName = _ownerProfile?.nameOrEmail ?? 'list owner';

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder:
          (context) => _CommitSheet(
            itemName: item.name,
            ownerName: ownerName,
            thumbnailUrl: item.thumbnailUrl,
            description: item.description,
            price: item.formattedPrice,
            retailerUrl: item.retailerUrl,
            category: item.category.displayName,
            priority: item.priority.displayName,
            ownerWantsNotification: _list.notifyOnCommit,
          ),
    );

    if (result != null && mounted) {
      final action = result['action'] as String;
      final note = result['note'] as String?;

      if (action == 'commit') {
        try {
          await ItemService().commitToItem(itemUid: item.uid, note: note);
          if (mounted) {
            AppNotification.success(context, 'Committed to "${item.name}"');
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to commit: $e');
          }
        }
      } else if (action == 'purchased') {
        try {
          await ItemService().purchaseItem(itemUid: item.uid, note: note);
          if (mounted) {
            AppNotification.success(
              context,
              'Marked "${item.name}" as purchased',
            );
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to mark as purchased: $e');
          }
        }
      }
    }
  }

  void _showOwnerStatusInfo(ListItem item, {required bool showPurchase}) {
    // Check if owner wants to see names based on notification settings
    final bool isAnonymous =
        showPurchase ? !_list.notifyOnPurchase : !_list.notifyOnCommit;

    // Get the appropriate name, avatar, and note based on which badge was tapped
    final String personName;
    final String? avatarUrl;
    final String? note;
    final String title;

    if (isAnonymous) {
      // Anonymous - don't show real name or avatar
      personName = 'Anonymous';
      avatarUrl = null;
      note = null;
      title = showPurchase ? 'Purchased' : 'Committed';
    } else if (showPurchase) {
      // Show purchase info
      personName = item.purchasedByDisplayName ?? 'Someone';
      avatarUrl = item.purchasedByAvatarUrl;
      note = item.purchaseNote;
      title = 'Purchased';
    } else {
      // Show commit info
      personName = item.claimedByDisplayName ?? 'Someone';
      avatarUrl = item.claimedByAvatarUrl;
      note = item.commitNote;
      title = 'Committed';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: false,
      useRootNavigator: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Text(
                              'Close',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar or icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              avatarUrl == null
                                  ? (isAnonymous
                                      ? AppColors.textSecondary.withValues(
                                        alpha: 0.1,
                                      )
                                      : AppColors.accent.withValues(alpha: 0.1))
                                  : null,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              avatarUrl != null
                                  ? Image.network(
                                    avatarUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.person,
                                          size: 40,
                                          color: AppColors.textSecondary,
                                        ),
                                  )
                                  : Icon(
                                    isAnonymous
                                        ? Icons.person
                                        : (showPurchase
                                            ? Icons.shopping_bag
                                            : Icons.card_giftcard),
                                    size: 40,
                                    color:
                                        isAnonymous
                                            ? AppColors.textSecondary
                                            : AppColors.accent,
                                  ),
                        ),
                      ),

                      // Person name
                      const SizedBox(height: 16),
                      Text(
                        'by $personName',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Note if exists
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '"$note"',
                          style: AppTypography.titleMedium.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          showPurchase
                              ? 'This item has been purchased.'
                              : 'This item has been reserved.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _openCommitStatus(ListItem item, {int? initialTab}) async {
    final ownerName = _ownerProfile?.nameOrEmail ?? 'list owner';
    final isMyCommit = item.claimedByUserId == SupabaseService.currentUserId;

    // Use provided initialTab, or determine based on item status
    final tabIndex = initialTab ?? (item.isPurchased ? 1 : 0);

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder:
          (context) => _CommitSheet(
            itemName: item.name,
            ownerName: ownerName,
            thumbnailUrl: item.thumbnailUrl,
            item: item,
            initialTab: tabIndex,
            ownerWantsNotification: _list?.notifyOnCommit ?? true,
            isMyCommit: isMyCommit,
          ),
    );

    if (result != null && mounted) {
      final action = result['action'] as String;

      if (action == 'revoke') {
        try {
          await ItemService().uncommitFromItem(item.uid);
          if (mounted) {
            AppNotification.success(context, 'Commitment revoked');
            _refreshItems();
          }
        } catch (e) {
          if (mounted) {
            AppNotification.error(context, 'Failed to revoke: $e');
          }
        }
      }
    }
  }

  void _addItem() async {
    await AddItemSheet.show(context, selectedList: _list);
    // Refresh items after the sheet is closed
    _refreshItems();
  }

  Widget _buildSelectableItem(ListItem item, bool isSelected, int index) {
    // Calculate position for grouped card style
    final itemCount = _filteredItems.length;
    ItemPosition position;
    if (itemCount == 1) {
      position = ItemPosition.only;
    } else if (index == 0) {
      position = ItemPosition.first;
    } else if (index == itemCount - 1) {
      position = ItemPosition.last;
    } else {
      position = ItemPosition.middle;
    }

    BorderRadius borderRadius;
    const radius = Radius.circular(12);
    switch (position) {
      case ItemPosition.first:
        borderRadius = const BorderRadius.only(
          topLeft: radius,
          topRight: radius,
        );
        break;
      case ItemPosition.last:
        borderRadius = const BorderRadius.only(
          bottomLeft: radius,
          bottomRight: radius,
        );
        break;
      case ItemPosition.middle:
        borderRadius = BorderRadius.zero;
        break;
      case ItemPosition.only:
        borderRadius = BorderRadius.circular(12);
        break;
    }

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItemUids.remove(item.uid);
          } else {
            _selectedItemUids.add(item.uid);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1,
            ),
            right: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1,
            ),
            top:
                position == ItemPosition.first || position == ItemPosition.only
                    ? BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: 1,
                    )
                    : BorderSide.none,
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                  width: 2,
                ),
              ),
              child:
                  isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 12),
            // Item image
            if (item.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.thumbnailUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        color: AppColors.surfaceVariant,
                        child: Icon(Icons.image, color: AppColors.textHint),
                      ),
                ),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.category.icon,
                  color: item.category.color,
                  size: 24,
                ),
              ),
            const SizedBox(width: 12),
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.price != null)
                    Text(
                      item.formattedPrice,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            // Priority indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.priority.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.priority.displayName,
                style: AppTypography.bodySmall.copyWith(
                  color: item.priority.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrioritySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: false,
      useRootNavigator: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header using same style as BottomSheetHeader
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Title - centered
                      Text(
                        'Set priority',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      // Close button on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: PhosphorIcon(
                              PhosphorIcons.xCircle(),
                              color: Colors.white70,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Priority options (reversed: high to low, then none)
                ...ItemPriority.values.reversed.toList().asMap().entries.map((
                  entry,
                ) {
                  final index = entry.key;
                  final priority = entry.value;
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(height: 1, color: AppColors.divider),
                      ListTile(
                        leading: PhosphorIcon(
                          priority.icon,
                          color: priority.color,
                          size: 28,
                        ),
                        title: Text(
                          priority.displayName,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _setSelectedItemsPriority(priority);
                        },
                      ),
                    ],
                  );
                }),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
    );
  }

  Future<void> _setSelectedItemsPriority(ItemPriority priority) async {
    try {
      for (final itemUid in _selectedItemUids) {
        await ItemService().updateItem(uid: itemUid, priority: priority);
      }

      AppNotification.success(
        context,
        'Updated ${_selectedItemUids.length} items to ${priority.displayName}',
      );

      setState(() {
        _isMultiSelectMode = false;
        _selectedItemUids.clear();
      });

      _refreshItems();
    } catch (e) {
      AppNotification.error(context, 'Failed to update priority: $e');
    }
  }

  void _deleteSelectedItems() async {
    final count = _selectedItemUids.length;
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete $count ${count == 1 ? 'item' : 'items'}?',
      content:
          'Are you sure you want to delete ${count == 1 ? 'this item' : 'these items'}?',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        for (final itemUid in _selectedItemUids) {
          await ItemService().deleteItem(itemUid);
        }

        AppNotification.success(context, 'Deleted $count items');

        setState(() {
          _isMultiSelectMode = false;
          _selectedItemUids.clear();
        });

        _refreshItems();
      } catch (e) {
        AppNotification.error(context, 'Failed to delete items: $e');
      }
    }
  }
}

/// Sheet for committing to or marking an item as purchased
class _CommitSheet extends StatefulWidget {
  final String itemName;
  final String ownerName;
  final String? thumbnailUrl;
  final String? description;
  final String? price;
  final String? retailerUrl;
  final String? category;
  final String? priority;
  final int initialTab;
  final bool ownerWantsNotification;
  final ListItem? item;
  final bool isMyCommit;

  const _CommitSheet({
    required this.itemName,
    required this.ownerName,
    this.thumbnailUrl,
    this.description,
    this.price,
    this.retailerUrl,
    this.category,
    this.priority,
    this.initialTab = 0,
    this.ownerWantsNotification = true,
    this.item,
    this.isMyCommit = false,
  });

  @override
  State<_CommitSheet> createState() => _CommitSheetState();
}

class _CommitSheetState extends State<_CommitSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  bool _notifyFriends = true;

  String get _ownerFirstName => widget.ownerName.split(' ').first;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
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
                // Cancel button row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
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
    // Check if viewing an existing commitment by current user
    if (widget.isMyCommit) {
      return _buildExistingCommitView();
    }

    // Check if someone else has committed to this item
    final item = widget.item;
    if (item != null && item.claimedByUserId != null) {
      return _buildOtherUserCommitView(item);
    }

    return _buildNewCommitView();
  }

  Widget _buildOtherUserCommitView(ListItem item) {
    final committerName = item.claimedByDisplayName ?? 'Someone';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          if (widget.thumbnailUrl != null)
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.thumbnailUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 40,
                          color: Colors.brown.shade700,
                        ),
                      ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: Colors.brown.shade700,
              ),
            ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Committed',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Committer info
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

          // Show commit note if available
          if (item.commitNote != null && item.commitNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note from $committerName',
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.brown.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.commitNote!,
                    style: AppTypography.bodyLarge.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingCommitView() {
    final commitNote = widget.item?.commitNote;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          if (widget.thumbnailUrl != null)
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.thumbnailUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: 20),

          // Title text
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

          // Show note if one exists
          if (commitNote != null && commitNote.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your note',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    commitNote,
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Owner notification status (past tense)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    widget.ownerWantsNotification
                        ? PhosphorIcons.bellRinging()
                        : PhosphorIcons.bellSlash(),
                    size: 22,
                    color:
                        widget.ownerWantsNotification
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.ownerWantsNotification
                          ? '$_ownerFirstName was notified'
                          : '$_ownerFirstName was not notified',
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
          ),

          const SizedBox(height: 24),

          // Revoke button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final confirmed = await AppDialog.show(
                  context,
                  title: 'Revoke commitment?',
                  content:
                      'Are you sure you want to revoke your commitment to this item?',
                  cancelText: 'Cancel',
                  confirmText: 'Revoke',
                  isDestructive: true,
                );
                if (confirmed && context.mounted) {
                  Navigator.pop(context, {'action': 'revoke'});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Row(
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

  Widget _buildNewCommitView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          if (widget.thumbnailUrl != null)
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.thumbnailUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Icon(
                Icons.card_giftcard,
                size: 40,
                color: AppColors.accent,
              ),
            ),
          const SizedBox(height: 20),

          // Title text
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
          Center(
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
                        onChanged:
                            (value) =>
                                setState(() => _notifyFriends = value ?? false),
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
          ),

          const SizedBox(height: 16),

          // Owner notification status
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    widget.ownerWantsNotification
                        ? PhosphorIcons.bellRinging()
                        : PhosphorIcons.bellSlash(),
                    size: 22,
                    color:
                        widget.ownerWantsNotification
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.ownerWantsNotification
                          ? '$_ownerFirstName will be notified automatically'
                          : '$_ownerFirstName has chosen not to be notified. They will see that someone has committed, but not who.',
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
          ),

          const SizedBox(height: 20),

          // Note field
          TextField(
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
                borderSide: BorderSide(color: Colors.amber.shade700),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: AppTypography.bodyLarge.copyWith(fontSize: 16),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Commit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => Navigator.pop(context, {
                    'action': 'commit',
                    'notifyFriends': _notifyFriends,
                    'note':
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                  }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Row(
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

  Widget _buildPurchasedTab() {
    final item = widget.item;

    // Check if item is purchased
    if (item != null && item.isPurchased) {
      final isMyPurchase =
          item.purchasedByUserId == SupabaseService.currentUserId;
      if (isMyPurchase) {
        return _buildMyPurchaseView(item);
      } else {
        return _buildOtherUserPurchaseView(item);
      }
    }

    // Show "mark as purchased" form
    return _buildNewPurchaseView();
  }

  Widget _buildMyPurchaseView(ListItem item) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          _buildPurchaseIcon(),
          const SizedBox(height: 20),

          // Title
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

          // Note if exists
          if (item.purchaseNote != null && item.purchaseNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your note',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.purchaseNote!,
                    style: AppTypography.bodyLarge.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherUserPurchaseView(ListItem item) {
    final purchaserName = item.purchasedByDisplayName ?? 'Someone';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          _buildPurchaseIcon(),
          const SizedBox(height: 20),

          // Title
          Text(
            'Purchased',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Purchaser info
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
            'This item has already been purchased. You can still view the item details.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          // Note if exists
          if (item.purchaseNote != null && item.purchaseNote!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note from $purchaserName',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.purchaseNote!,
                    style: AppTypography.bodyLarge.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchaseIcon() {
    if (widget.thumbnailUrl != null) {
      return Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: ClipOval(
          child: Image.network(
            widget.thumbnailUrl!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
          ),
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildNewPurchaseView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon
          _buildPurchaseIcon(),
          const SizedBox(height: 20),

          // Body text
          Text(
            'Have you purchased this item?',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Mark this item as purchased to let others know it\'s been taken care of.',
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Notify friends checkbox
          Center(
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
                        onChanged:
                            (value) =>
                                setState(() => _notifyFriends = value ?? false),
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
          ),

          const SizedBox(height: 16),

          // Owner notification status
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    widget.ownerWantsNotification
                        ? PhosphorIcons.bellRinging()
                        : PhosphorIcons.bellSlash(),
                    size: 22,
                    color:
                        widget.ownerWantsNotification
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.ownerWantsNotification
                          ? '$_ownerFirstName will be notified automatically'
                          : '$_ownerFirstName has chosen not to be notified. They will see that someone has purchased, but not who.',
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
          ),

          const SizedBox(height: 20),

          // Note field
          TextField(
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: AppTypography.bodyLarge.copyWith(fontSize: 16),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Purchased button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => Navigator.pop(context, {
                    'action': 'purchased',
                    'notifyFriends': _notifyFriends,
                    'note':
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                  }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 22),
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

          const SizedBox(height: 16),

          // Link to commit tab
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: Text(
              'Commit to this item only',
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

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Thumbnail or fallback icon (same style as other tabs)
          if (widget.thumbnailUrl != null)
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.thumbnailUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Icon(
                Icons.info_outline,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(height: 20),

          // Item name (no label)
          Text(
            widget.itemName,
            style: AppTypography.titleLarge.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          // Price (no label)
          if (widget.price != null && widget.price!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.price!,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Priority (no label)
          if (widget.priority != null && widget.priority != 'No priority') ...[
            const SizedBox(height: 8),
            Text(
              'Priority: ${widget.priority}',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Description
          if (widget.description != null && widget.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.description!,
              style: AppTypography.bodyLarge.copyWith(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],

          // Link button
          if (widget.retailerUrl != null && widget.retailerUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(widget.retailerUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Go to link',
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
        ],
      ),
    );
  }
}

/// Sheet for managing which friends have access to a list
class _ManageFriendsSheet extends StatefulWidget {
  final WishList list;
  final List<Friend> friends;
  final ListShareService listShareService;
  final VoidCallback onComplete;

  const _ManageFriendsSheet({
    required this.list,
    required this.friends,
    required this.listShareService,
    required this.onComplete,
  });

  @override
  State<_ManageFriendsSheet> createState() => _ManageFriendsSheetState();
}

class _ManageFriendsSheetState extends State<_ManageFriendsSheet> {
  final _searchController = TextEditingController();
  final Map<String, bool> _friendShareStatus = {};
  List<Friend> _filteredFriends = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.friends;
    _loadCurrentShares();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentShares() async {
    final sharedUsers = await widget.listShareService.getUsersForList(
      widget.list.uid,
    );

    for (final friend in widget.friends) {
      _friendShareStatus[friend.friendUserId] = sharedUsers.contains(
        friend.friendUserId,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterFriends(String query) {
    if (query.isEmpty) {
      setState(() => _filteredFriends = widget.friends);
    } else {
      final lowerQuery = query.toLowerCase();
      setState(() {
        _filteredFriends =
            widget.friends.where((friend) {
              final name = friend.displayName.toLowerCase();
              return name.contains(lowerQuery);
            }).toList();
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      for (final entry in _friendShareStatus.entries) {
        final friendId = entry.key;
        final shouldShare = entry.value;

        if (shouldShare) {
          await widget.listShareService.shareListWithUser(
            widget.list.uid,
            friendId,
          );
        } else {
          await widget.listShareService.unshareListWithUser(
            widget.list.uid,
            friendId,
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(context, 'Friends updated');
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error updating friends: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.error(context, 'Failed to update friends');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Manage friends',
      confirmText: 'Save',
      onCancel: () => Navigator.pop(context),
      onConfirm: _isSaving ? null : _saveChanges,
      isLoading: _isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Select friends who can see "${widget.list.title}":',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: _filterFriends,
          ),
          const SizedBox(height: 16),

          // Friends list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (widget.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'You don\'t have any friends yet.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            )
          else
            ..._filteredFriends.map((friend) {
              final isShared = _friendShareStatus[friend.friendUserId] ?? false;
              return _buildFriendTile(friend, isShared);
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Friend friend, bool isShared) {
    return InkWell(
      onTap: () {
        setState(() {
          _friendShareStatus[friend.friendUserId] = !isShared;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isShared ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isShared ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child:
                  isShared
                      ? PhosphorIcon(
                        PhosphorIcons.check(PhosphorIconsStyle.bold),
                        size: 16,
                        color: Colors.white,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            // Avatar
            _buildAvatar(friend),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(friend.displayName, style: AppTypography.titleMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Friend friend) {
    if (friend.friendAvatarUrl != null && friend.friendAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(friend.friendAvatarUrl!),
        backgroundColor: AppColors.claimedBackground,
      );
    }

    final colors = [
      AppColors.categoryEvents,
      AppColors.categoryTrips,
      AppColors.categoryStuff,
      AppColors.categoryCrafted,
      AppColors.categoryMeals,
      AppColors.primary,
    ];
    final colorIndex = friend.id % colors.length;
    final color = colors[colorIndex];

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        friend.initials,
        style: AppTypography.titleMedium.copyWith(color: color),
      ),
    );
  }
}
