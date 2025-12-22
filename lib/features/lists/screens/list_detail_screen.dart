import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/item_service.dart';
import '../../../services/list_service.dart';
import '../../../services/lists_notifier.dart';
import '../../../widgets/add_item_sheet.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/bottom_sheet_header.dart';
import '../../../widgets/edit_item_sheet.dart';
import '../../../widgets/item_card.dart';

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
  final bool _isOwner = true; // TODO: Determine from auth
  String _sortOption = 'newest';
  ItemCategory? _selectedCategoryFilter; // null = All

  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedItemUids = {};

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
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

      setState(() {
        _list = list;
        _items = items;
        _isLoading = false;
      });

      // Start fade-in animation after content loads
      _fadeController.forward();

      // Show buttons after a brief delay to avoid spin animation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _showButtons = true);
        }
      });
    } catch (e) {
      debugPrint('Error loading list: $e');
      if (mounted) {
        context.go('/lists');
      }
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
        body:
            const SizedBox.shrink(), // Empty instead of spinner for smoother transition
      );
    }

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
                  children: [
                    // Solid color base (shows while loading)
                    Container(color: AppColors.primary),
                    // Fading image on top
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Image.network(
                            _list.coverImageUrl!,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
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
        toolbarHeight: _list.description != null ? 70 : kToolbarHeight,
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
                                  _list.isPublic
                                      ? PhosphorIcons.usersThree()
                                      : PhosphorIcons.lock(),
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _list.isPublic ? 'Public' : 'Private',
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
                                  onTap: () => _openItemDetail(item),
                                  onClaimTap: () => _claimItem(item),
                                  onLinkTap: item.retailerUrl != null
                                      ? () => _openProductLink(item.retailerUrl!)
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
                  icon: PhosphorIcon(
                    PhosphorIcons.heartStraight(),
                    color: Colors.white,
                  ),
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
      case 'delete':
        _confirmDeleteList();
        break;
    }
  }

  void _showEditListSheet() {
    final titleController = TextEditingController(text: _list.title);
    final descriptionController = TextEditingController(
      text: _list.description ?? '',
    );
    var visibility = _list.visibility;
    var isLoading = false;

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

              return DefaultTabController(
                length: 2,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shared header component
                      BottomSheetHeader(
                        title: 'Edit list',
                        confirmText: 'Save',
                        onCancel: () => Navigator.pop(context),
                        onConfirm: handleSave,
                        isLoading: isLoading,
                      ),

                      // Tabs
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          labelStyle: AppTypography.titleMedium,
                          unselectedLabelStyle: AppTypography.titleMedium,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'List details'),
                            Tab(text: 'Set date'),
                          ],
                        ),
                      ),

                      // Tab content
                      Flexible(
                        child: TabBarView(
                          children: [
                            // Tab 1: Details
                            SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                24 + MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title field
                                  Text(
                                    'List name',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: titleController,
                                    style: AppTypography.titleMedium,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'e.g. Gift ideas, Wish list, Things to do etc...',
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Description field
                                  Text(
                                    'Description (optional)',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: descriptionController,
                                    style: AppTypography.titleMedium,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    minLines: 2,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'e.g. These are a few of my favourite things',
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Cover image
                                  Text(
                                    'Cover image (optional)',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  buildCoverImagePicker(),
                                  const SizedBox(height: 24),

                                  // Visibility
                                  Text(
                                    'Visibility',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Public option
                                  GestureDetector(
                                    onTap:
                                        () => setSheetState(
                                          () =>
                                              visibility =
                                                  ListVisibility.public,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              visibility ==
                                                      ListVisibility.public
                                                  ? AppColors.primary
                                                  : AppColors.divider,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.usersThree(),
                                            size: 28,
                                            color:
                                                visibility ==
                                                        ListVisibility.public
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Public',
                                                  style:
                                                      AppTypography.titleMedium,
                                                ),
                                                Text(
                                                  'Anyone with the link can see',
                                                  style: AppTypography
                                                      .bodyMedium
                                                      .copyWith(
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (visibility ==
                                              ListVisibility.public)
                                            PhosphorIcon(
                                              PhosphorIcons.checkCircle(
                                                PhosphorIconsStyle.fill,
                                              ),
                                              color: AppColors.primary,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Private option
                                  GestureDetector(
                                    onTap:
                                        () => setSheetState(
                                          () =>
                                              visibility =
                                                  ListVisibility.private,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              visibility ==
                                                      ListVisibility.private
                                                  ? AppColors.primary
                                                  : AppColors.divider,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.lock(),
                                            size: 28,
                                            color:
                                                visibility ==
                                                        ListVisibility.private
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Private',
                                                  style:
                                                      AppTypography.titleMedium,
                                                ),
                                                Text(
                                                  'Only people you share with can see',
                                                  style: AppTypography
                                                      .bodyMedium
                                                      .copyWith(
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (visibility ==
                                              ListVisibility.private)
                                            PhosphorIcon(
                                              PhosphorIcons.checkCircle(
                                                PhosphorIconsStyle.fill,
                                              ),
                                              color: AppColors.primary,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),

                            // Tab 2: Event
                            SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                24 + MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event date section
                                  Text(
                                    'Event date',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Set a date for birthdays, weddings, holidays, etc.',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Date picker row
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            eventDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
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
                                      padding: const EdgeInsets.all(16),
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
                                            size: 24,
                                            color:
                                                eventDate != null
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              eventDate != null
                                                  ? _formatEventDate(eventDate!)
                                                  : 'Select a date',
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                    color:
                                                        eventDate != null
                                                            ? AppColors
                                                                .textPrimary
                                                            : AppColors
                                                                .textPrimary,
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
                                                size: 24,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Recurring section
                                  Text(
                                    'Recurring',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enable for events that happen every year',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Recurring toggle
                                  GestureDetector(
                                    onTap:
                                        () => setSheetState(
                                          () => isRecurring = !isRecurring,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              isRecurring
                                                  ? AppColors.primary
                                                  : AppColors.divider,
                                          width: isRecurring ? 2 : 1,
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
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.arrowsClockwise(),
                                            size: 24,
                                            color:
                                                isRecurring
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Recurring annually',
                                                  style: AppTypography
                                                      .titleSmall
                                                      .copyWith(
                                                        color:
                                                            isRecurring
                                                                ? AppColors
                                                                    .primary
                                                                : AppColors
                                                                    .textPrimary,
                                                      ),
                                                ),
                                                Text(
                                                  'For birthdays and yearly events',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PhosphorIcon(
                                            isRecurring
                                                ? PhosphorIcons.checkCircle(
                                                  PhosphorIconsStyle.fill,
                                                )
                                                : PhosphorIcons.circle(),
                                            size: 24,
                                            color:
                                                isRecurring
                                                    ? AppColors.primary
                                                    : AppColors.divider,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Info about event date
                                  if (eventDate != null) ...[
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.info(),
                                            size: 24,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              isRecurring
                                                  ? 'This date will repeat every year'
                                                  : 'This is a one-time event',
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    _showEditItemSheet(item);
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
      onSaved: () {
        _refreshItems();
        AppNotification.success(context, 'Item updated');
      },
      onDeleted: () => _confirmDeleteItem(item),
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

  void _claimItem(ListItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Claim Item'),
            content: Text('Do you want to claim "${item.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Claim item
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Claimed "${item.name}"')),
                  );
                },
                child: const Text('Claim'),
              ),
            ],
          ),
    );
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
      content: 'Are you sure you want to delete ${count == 1 ? 'this item' : 'these items'}?',
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
