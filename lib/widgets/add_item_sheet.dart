import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/price_formatter.dart';
import '../models/list_item.dart';
import '../models/wish_list.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';
import '../services/lists_notifier.dart';
import '../services/user_settings_service.dart';
import '../services/image_upload_service.dart';
import 'app_notification.dart';

/// Unified Add Item sheet with tabs for Quick Add, Amazon Search, and Paste Link
class AddItemSheet extends StatefulWidget {
  /// Optional pre-selected list (when opened from a specific list)
  final WishList? selectedList;

  const AddItemSheet({super.key, this.selectedList});

  /// Show the add item sheet
  static Future<void> show(BuildContext context, {WishList? selectedList}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => AddItemSheet(selectedList: selectedList),
    );
  }

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  final _listSearchController = TextEditingController();
  final _amazonSearchController = TextEditingController();
  final _quickAddController = TextEditingController();
  final _quickAddFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  ItemCategory _selectedCategory = ItemCategory.stuff;
  ItemPriority _selectedPriority = ItemPriority.none;
  bool _isLoading = false;
  bool _isLoadingLists = true;

  // Image handling
  File? _selectedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';
  String? _uploadedThumbnailUrl;
  String? _uploadedMainImageUrl;
  final ImageUploadService _imageService = ImageUploadService();

  List<WishList> _lists = [];
  List<WishList> _filteredLists = [];
  WishList? _selectedList;
  bool _showListDropdown = false;

  // Quick add items (name + category + priority)
  List<({String name, ItemCategory category, ItemPriority priority})>
  _quickAddItems = [];
  ItemCategory _quickAddCategory = ItemCategory.stuff;
  ItemPriority _quickAddPriority = ItemPriority.none;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedList = widget.selectedList;
    _loadLists();
    _listSearchController.addListener(_filterLists);
    _priceFocusNode.addListener(_onPriceFocusChange);
  }

  void _onPriceFocusChange() {
    if (!_priceFocusNode.hasFocus) {
      // Format price on blur
      final formatted = PriceFormatter.format(_priceController.text);
      if (formatted != _priceController.text) {
        _priceController.text = formatted;
      }
    }
  }

  Future<void> _loadLists() async {
    try {
      final lists = await ListService().getUserLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _filteredLists = lists;
          // If no list was pre-selected, select the first one
          if (_selectedList == null && lists.isNotEmpty) {
            _selectedList = lists.first;
          }
          _isLoadingLists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLists = false);
      }
    }
  }

  void _filterLists() {
    final query = _listSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLists = _lists;
      } else {
        _filteredLists =
            _lists
                .where((list) => list.title.toLowerCase().contains(query))
                .toList();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    _listSearchController.dispose();
    _amazonSearchController.dispose();
    _quickAddController.dispose();
    _quickAddFocusNode.dispose();
    _priceFocusNode.removeListener(_onPriceFocusChange);
    _priceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with black background
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Title - centered
                      Text(
                        'Add item',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),

                      // Buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cancel button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
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

                          // Add button - pill style
                          GestureDetector(
                            onTap: _isLoading ? null : _saveItem,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                        'Add',
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                    fontSize: 18,
                  ),
                  tabs: [
                    const Tab(text: 'Item details'),
                    const Tab(text: 'Quick add'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.magnifyingGlass(),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text('Amazon'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuickAddTab(),
                _buildPasteLinkTab(),
                _buildAmazonSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // List selector (only show if not pre-selected)
            if (widget.selectedList == null) ...[
              _buildListSelector(),
              const SizedBox(height: 24),
            ],

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Item name'),
              textCapitalization: TextCapitalization.words,
              style: AppTypography.titleMedium,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
              ),
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: 16),

            // Price and Priority row
            Row(
              children: [
                // Price field
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Price',
                      prefixText: '${UserSettingsService().currencySymbol} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [PriceInputFormatter()],
                    style: AppTypography.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                // Priority dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ItemPriority>(
                        value: _selectedPriority,
                        isExpanded: true,
                        icon: PhosphorIcon(
                          PhosphorIcons.caretDown(),
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        items:
                            ItemPriority.values.map((priority) {
                              return DropdownMenuItem<ItemPriority>(
                                value: priority,
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      priority.icon,
                                      color: priority.color,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        priority.displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPriority = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image picker
            _buildImagePicker(),
            const SizedBox(height: 16),

            // URL field
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'Product URL (optional)',
              ),
              keyboardType: TextInputType.url,
              style: AppTypography.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Category selection
            Text('Category', style: AppTypography.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  ItemCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 18,
                              color: isSelected ? Colors.white : category.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category.displayName,
                              style: AppTypography.bodyMedium.copyWith(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmazonSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // List selector (only show if not pre-selected)
          if (widget.selectedList == null) ...[
            _buildListSelector(),
            const SizedBox(height: 24),
          ],

          // Search field
          TextField(
            controller: _amazonSearchController,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search Amazon...',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: PhosphorIcon(
                  PhosphorIcons.magnifyingGlass(),
                  color: AppColors.textSecondary,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon:
                  _amazonSearchController.text.isNotEmpty
                      ? IconButton(
                        icon: PhosphorIcon(PhosphorIcons.x()),
                        onPressed: () {
                          _amazonSearchController.clear();
                          setState(() {});
                        },
                      )
                      : null,
            ),
            onSubmitted: _searchAmazon,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),

          // Search results placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.shoppingCart(),
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for products on Amazon',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items will be added with affiliate links',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
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

  Widget _buildPasteLinkTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // List selector (only show if not pre-selected)
          if (widget.selectedList == null) ...[
            _buildListSelector(),
            const SizedBox(height: 24),
          ],

          // Category selection for quick add
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ItemCategory.values.map((category) {
                    final isSelected = _quickAddCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap:
                            () => setState(() => _quickAddCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon,
                                size: 16,
                                color:
                                    isSelected ? Colors.white : category.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                category.displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Priority selection for quick add
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ItemPriority.values.map((priority) {
                    final isSelected = _quickAddPriority == priority;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap:
                            () => setState(() => _quickAddPriority = priority),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? priority.color : Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? priority.color
                                      : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(
                                priority.icon,
                                size: 16,
                                color:
                                    isSelected ? Colors.white : priority.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                priority.displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Quick add input
          TextField(
            controller: _quickAddController,
            focusNode: _quickAddFocusNode,
            style: AppTypography.titleMedium,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type item name and press enter...',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.textHint,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PhosphorIcon(
                  PhosphorIcons.arrowElbowDownLeft(),
                  color: AppColors.textHint,
                  size: 22,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: _addQuickItem,
          ),
          const SizedBox(height: 24),

          // Added items list
          Expanded(
            child:
                _quickAddItems.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.lightning(),
                            size: 48,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Quickly add items',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type a name and press enter',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      itemCount: _quickAddItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _quickAddItems[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.category.icon,
                                color: item.category.color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              if (item.priority != ItemPriority.none) ...[
                                PhosphorIcon(
                                  item.priority.icon,
                                  color: item.priority.color,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: AppTypography.bodyLarge,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _quickAddItems.removeAt(index);
                                  });
                                },
                                child: PhosphorIcon(
                                  PhosphorIcons.x(),
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _addQuickItem(String value) {
    final itemName = value.trim();
    if (itemName.isEmpty) return;

    // Clear input and refocus immediately for quick continuous adding
    _quickAddController.clear();
    _quickAddFocusNode.requestFocus();

    // Add to local list (will be saved when "Add" button is tapped)
    setState(() {
      _quickAddItems.add((
        name: itemName,
        category: _quickAddCategory,
        priority: _quickAddPriority,
      ));
    });
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image (optional)', style: AppTypography.titleMedium),
        const SizedBox(height: 8),

        if (_isUploadingImage) ...[
          // Upload progress indicator
          Container(
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
                    value: _uploadProgress,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _uploadStatus,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_selectedImage != null || _uploadedThumbnailUrl != null) ...[
          // Selected/uploaded image preview
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : Image.network(
                          _uploadedThumbnailUrl!,
                          fit: BoxFit.cover,
                        ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _removeImage,
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
          ),
        ] else ...[
          // Image picker buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.gallery),
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
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gallery',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
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
                  onTap: () => _pickImage(ImageSource.camera),
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
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Camera',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
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
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _selectedImage = file;
      _uploadedThumbnailUrl = null;
      _uploadedMainImageUrl = null;
    });

    // Start upload immediately
    await _uploadImage(file);
  }

  Future<void> _uploadImage(File file) async {
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0;
      _uploadStatus = 'Starting...';
    });

    try {
      final result = await _imageService.processAndUpload(
        file,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatus = status;
            });
          }
        },
      );

      if (mounted && result != null) {
        setState(() {
          _isUploadingImage = false;
          _uploadedThumbnailUrl = result.thumbnailUrl;
          _uploadedMainImageUrl = result.mainImageUrl;
          _selectedImage = null; // Clear local file, use uploaded URLs
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadProgress = 0;
          _uploadStatus = '';
        });
        AppNotification.error(context, 'Failed to upload image');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedThumbnailUrl = null;
      _uploadedMainImageUrl = null;
    });
  }

  Widget _buildListSelector() {
    if (_isLoadingLists) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_lists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          'No lists yet. Create one first!',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected list display / dropdown trigger
        GestureDetector(
          onTap: () => setState(() => _showListDropdown = !_showListDropdown),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _showListDropdown ? AppColors.primary : AppColors.divider,
                width: _showListDropdown ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.listBullets(),
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedList?.title ?? 'Select a list',
                    style: AppTypography.bodyLarge.copyWith(
                      color:
                          _selectedList != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                    ),
                  ),
                ),
                PhosphorIcon(
                  _showListDropdown
                      ? PhosphorIcons.caretUp()
                      : PhosphorIcons.caretDown(),
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Dropdown with search
        if (_showListDropdown) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _listSearchController,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search lists...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: PhosphorIcon(
                          PhosphorIcons.magnifyingGlass(),
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // List items
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredLists.length,
                    itemBuilder: (context, index) {
                      final list = _filteredLists[index];
                      final isSelected = _selectedList?.uid == list.uid;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedList = list;
                            _showListDropdown = false;
                            _listSearchController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color:
                              isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : null,
                          child: Row(
                            children: [
                              PhosphorIcon(
                                isSelected
                                    ? PhosphorIcons.star(
                                      PhosphorIconsStyle.fill,
                                    )
                                    : PhosphorIcons.star(),
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  list.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                PhosphorIcon(
                                  PhosphorIcons.check(),
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // No results message
                if (_filteredLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No lists found',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _searchAmazon(String query) {
    if (query.isEmpty) return;
    // TODO: Implement Amazon PA-API search
    AppNotification.show(
      context,
      message: 'Searching for "$query"...',
      icon: PhosphorIcons.magnifyingGlass(),
    );
  }

  Future<void> _saveItem() async {
    // Check which tab is active
    if (_tabController.index == 1) {
      // Quick Add tab - save all accumulated items

      // First add current input if not empty
      final currentInput = _quickAddController.text.trim();
      if (currentInput.isNotEmpty) {
        _addQuickItem(currentInput);
      }

      if (_quickAddItems.isEmpty) {
        AppNotification.error(context, 'Add some items first');
        return;
      }

      if (_selectedList == null) {
        AppNotification.error(context, 'Please select a list first');
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Save all items to database
        for (final item in _quickAddItems) {
          await ItemService().createItem(
            listId: _selectedList!.id,
            name: item.name,
            category: item.category,
            priority: item.priority,
          );
        }

        if (mounted) {
          ListsNotifier().notifyItemCountChanged();
          Navigator.pop(context);
          AppNotification.success(
            context,
            'Added ${_quickAddItems.length} item${_quickAddItems.length == 1 ? '' : 's'} to "${_selectedList!.title}"',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          AppNotification.error(context, 'Failed to add items: $e');
        }
      }
      return;
    }

    // Item tab - validate form
    if (_formKey.currentState!.validate()) {
      if (_selectedList == null) {
        AppNotification.error(context, 'Please select a list');
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Parse price if provided
        double? price;
        if (_priceController.text.isNotEmpty) {
          price = double.tryParse(_priceController.text.replaceAll(',', '.'));
        }

        // Save item via ItemService
        await ItemService().createItem(
          listId: _selectedList!.id,
          name: _nameController.text.trim(),
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          price: price,
          currency: UserSettingsService().currency.code,
          retailerUrl:
              _urlController.text.trim().isEmpty
                  ? null
                  : _urlController.text.trim(),
          thumbnailUrl: _uploadedThumbnailUrl,
          mainImageUrl: _uploadedMainImageUrl,
          category: _selectedCategory,
          priority: _selectedPriority,
        );

        if (mounted) {
          ListsNotifier().notifyItemCountChanged();
          Navigator.pop(context);
          AppNotification.success(
            context,
            'Added "${_nameController.text}" to "${_selectedList!.title}"',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          AppNotification.error(context, 'Failed to add item: $e');
        }
      }
    }
  }
}
