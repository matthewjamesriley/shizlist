import 'dart:io';
import 'app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/price_formatter.dart';
import '../models/list_item.dart';
import '../models/wish_list.dart';
import '../services/amazon_service.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';
import '../services/lists_notifier.dart';
import '../services/user_settings_service.dart';
import '../services/image_upload_service.dart';
import 'amazon_browser_screen.dart';
import 'app_notification.dart';

/// Unified Add Item sheet with tabs for Quick Add, Amazon Search, and Paste Link
class AddItemSheet extends StatefulWidget {
  /// Optional pre-selected list (when opened from a specific list)
  final WishList? selectedList;

  /// Remember the last selected tab across sessions
  static int _lastSelectedTab = 0;

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

  // Flag to prevent re-entrant URL extraction
  bool _isExtractingUrl = false;

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

  // Product info fetching for Item details tab
  bool _isFetchingProductInfo = false;

  // How this works expandable section
  bool _showHowItWorks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: AddItemSheet._lastSelectedTab,
    );
    _tabController.addListener(_onTabChanged);
    _selectedList = widget.selectedList;
    _loadLists();
    _listSearchController.addListener(_filterLists);
    _priceFocusNode.addListener(_onPriceFocusChange);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      AddItemSheet._lastSelectedTab = _tabController.index;
    }
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

  /// Extract URL from text that may contain additional content
  /// e.g. "Check this out! https://example.com/product" -> "https://example.com/product"
  String _extractUrl(String text) {
    // Match http:// or https:// URLs
    // URL pattern: protocol + domain + optional path/query
    final urlRegex = RegExp(
      r'https?://[a-zA-Z0-9\-._~:/?#\[\]@!$&()*+,;=%]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      var url = match.group(0) ?? text;
      // Trim any trailing punctuation that shouldn't be part of URL
      url = url.replaceAll(RegExp(r'[,.\s]+$'), '');
      debugPrint('Extracted URL: $url');
      return url.trim();
    }
    return text;
  }

  /// Paste URL from clipboard, extracting if needed
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      var extracted = _extractUrl(clipboardData.text!);
      // Add https:// if no protocol present
      if (extracted.isNotEmpty &&
          !extracted.startsWith('http://') &&
          !extracted.startsWith('https://')) {
        extracted = 'https://$extracted';
      }
      _urlController.text = extracted;
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: extracted.length),
      );
      setState(() {}); // Refresh UI
    }
  }

  /// Open the product URL in browser
  Future<void> _openProductUrl() async {
    final urlString = _urlController.text.trim();
    if (urlString.isEmpty) return;

    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } else {
        if (mounted) {
          AppNotification.error(context, 'Could not open URL');
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Invalid URL');
      }
    }
  }

  /// Fetch product info from URL (Amazon or generic)
  Future<void> _fetchProductInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isFetchingProductInfo = true);

    try {
      Map<String, String?> info;
      bool isAmazon = false;

      // Check if it's an Amazon URL
      String resolvedUrl = url;
      if (AmazonService.isShortLink(url)) {
        resolvedUrl = await AmazonService.resolveShortLink(url);
      }

      if (AmazonService.isAmazonUrl(resolvedUrl)) {
        isAmazon = true;

        if (AmazonService.isSearchUrl(resolvedUrl)) {
          if (mounted) {
            setState(() => _isFetchingProductInfo = false);
            AppNotification.error(
              context,
              'This is a search page. Please select a specific product first.',
            );
          }
          return;
        }

        final asin = AmazonService.extractAsin(resolvedUrl);
        if (asin == null) {
          if (mounted) {
            setState(() => _isFetchingProductInfo = false);
            AppNotification.error(
              context,
              'Could not find product in this URL',
            );
          }
          return;
        }

        info = await AmazonService.fetchProductInfo(url);
      } else {
        // Use generic fetcher for non-Amazon URLs
        info = await AmazonService.fetchGenericProductInfo(url);
      }

      if (mounted) {
        bool foundAnyInfo = false;

        // Update name if found
        if (info['title'] != null && info['title']!.isNotEmpty) {
          _nameController.text = info['title']!;
          foundAnyInfo = true;
        }

        // Update price if found
        if (info['price'] != null && info['price']!.isNotEmpty) {
          _priceController.text = info['price']!;
          foundAnyInfo = true;
        }

        // Update URL with affiliate link (Amazon only)
        if (isAmazon && info['affiliateUrl'] != null) {
          _urlController.text = info['affiliateUrl']!;
        }

        // Download and upload image if found
        if (info['imageUrl'] != null && info['imageUrl']!.isNotEmpty) {
          foundAnyInfo = true;
          setState(() {
            _uploadStatus = 'Downloading image...';
            _isUploadingImage = true;
            _uploadProgress = 0.1;
          });

          try {
            final uploadResult = await _imageService.downloadAndUpload(
              info['imageUrl']!,
              onProgress: (progress, status) {
                if (mounted) {
                  setState(() {
                    _uploadProgress = progress;
                    _uploadStatus = status;
                  });
                }
              },
            );

            if (uploadResult != null && mounted) {
              setState(() {
                _uploadedThumbnailUrl = uploadResult.thumbnailUrl;
                _uploadedMainImageUrl = uploadResult.mainImageUrl;
                _isUploadingImage = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isUploadingImage = false);
              AppNotification.error(context, 'Failed to download image');
            }
          }
        }

        setState(() => _isFetchingProductInfo = false);

        if (!foundAnyInfo) {
          AppNotification.error(context, 'Unable to fetch product info');
        } else {
          AppNotification.success(context, 'Product info loaded');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingProductInfo = false);
        AppNotification.error(context, 'Failed to fetch product info');
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
    _tabController.removeListener(_onTabChanged);
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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

                const SizedBox(height: 10),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                    fontSize: 17,
                  ),
                  tabs: [
                    const Tab(text: 'Item details'),
                    const Tab(text: 'Amazon'),
                    const Tab(text: 'Quick add'),
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
                _buildAmazonSearchTab(),
                _buildPasteLinkTab(),
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
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
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

            // URL field at the top
            Text('Item link (optional)', style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://',
                suffixIcon: IconButton(
                  icon: Icon(
                    PhosphorIcons.clipboard(PhosphorIconsStyle.fill),
                    color: AppColors.accent,
                  ),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste from clipboard',
                ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTypography.bodyLarge,
              onChanged: (value) {
                // Prevent re-entrant calls while we're updating the text
                if (_isExtractingUrl) return;

                // Extract URL if text contains extra content (e.g. from share sheets)
                final extracted = _extractUrl(value);
                if (extracted != value) {
                  _isExtractingUrl = true;
                  _urlController.text = extracted;
                  _urlController.selection = TextSelection.fromPosition(
                    TextPosition(offset: extracted.length),
                  );
                  _isExtractingUrl = false;
                }
                setState(() {}); // Refresh to update button state
              },
            ),
            const SizedBox(height: 12),

            // Buttons row - show when URL is entered
            if (_urlController.text.trim().isNotEmpty)
              Row(
                children: [
                  // Get product info button (for any URL)
                  if (_urlController.text.trim().startsWith('http'))
                    Expanded(
                      child: AppButton.accent(
                        label:
                            _isFetchingProductInfo
                                ? 'Fetching...'
                                : 'Get product info',
                        onPressed:
                            !_isFetchingProductInfo ? _fetchProductInfo : null,
                        isLoading: _isFetchingProductInfo,
                        size: ButtonSize.small,
                      ),
                    ),
                  if (_urlController.text.trim().startsWith('http'))
                    const SizedBox(width: 12),
                  // View item button
                  Expanded(
                    child: AppButton.primary(
                      label: 'View item',
                      icon: PhosphorIcons.arrowSquareOut(),
                      size: ButtonSize.small,
                      onPressed: _openProductUrl,
                    ),
                  ),
                ],
              ),

            // How this works - expandable
            if (_urlController.text.trim().isEmpty) ...[
              const SizedBox(height: 0),
              GestureDetector(
                onTap: () => setState(() => _showHowItWorks = !_showHowItWorks),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.question(),
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How this works',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PhosphorIcon(
                      _showHowItWorks
                          ? PhosphorIcons.caretUp()
                          : PhosphorIcons.caretDown(),
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (_showHowItWorks) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionStep(
                        '1',
                        'Find a product on any website or app and copy the link from the share button or the address bar',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _buildInstructionStep(
                        '2',
                        'Paste any product link above by tapping the red clipboard icon',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _buildInstructionStep(
                        '3',
                        'Tap "Get product info" to auto-fill the name, price, image and so on...',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _buildInstructionStep(
                        '4',
                        'Enter any missing information, such as size, color, quantity, etc...',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _buildInstructionStep(
                        '5',
                        'Once you\'re happy, tap "Add"',
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

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
                          color: AppColors.textPrimary,
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
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List selector (only show if not pre-selected)
          if (widget.selectedList == null) ...[
            _buildListSelector(),
            const SizedBox(height: 24),
          ],

          // Browse Amazon button - primary action
          AppButton.accent(
            label: 'Browse Amazon',
            icon: PhosphorIcons.amazonLogo(),
            onPressed: _openAmazonBrowser,
          ),

          const SizedBox(height: 24),

          // How it works section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.info(),
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How it works',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  '1',
                  'Tap "Browse Amazon" to open the Amazon website',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                _buildInstructionStep(
                  '2',
                  'Search for the product you want, don\'t select \'Add to basket\' in Amazon, instead open the product page',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                _buildInstructionStep(
                  '3',
                  'Tap the "Add to list" button at the bottom of the screen',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                _buildInstructionStep(
                  '4',
                  'The product will be added to your list',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                //once you have finished
                _buildInstructionStep(
                  '5',
                  'Once you have finished, select X to close the browser and return to the app',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyLarge.copyWith(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _openAmazonBrowser() async {
    if (_selectedList == null) {
      AppNotification.error(context, 'Please select a list first');
      return;
    }

    await AmazonBrowserScreen.show(context, selectedList: _selectedList);

    // Items are added directly from the browser now
    // Just close the Add Item sheet when browser is closed
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPasteLinkTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),

          // Quick add input with priority dropdown
          Row(
            children: [
              // Text input
              Expanded(
                child: TextField(
                  controller: _quickAddController,
                  focusNode: _quickAddFocusNode,
                  style: AppTypography.titleMedium,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type item name...',
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
              ),
              const SizedBox(width: 12),
              // Priority dropdown (icon only)
              PopupMenuButton<ItemPriority>(
                onSelected: (value) {
                  setState(() => _quickAddPriority = value);
                },
                offset: const Offset(-8, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder:
                    (context) =>
                        ItemPriority.values.map((priority) {
                          return PopupMenuItem<ItemPriority>(
                            value: priority,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  priority.icon,
                                  color: priority.color,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  priority.displayName,
                                  style: AppTypography.titleMedium,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        _quickAddPriority.icon,
                        color: _quickAddPriority.color,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        PhosphorIcons.caretDown(),
                        color: AppColors.textPrimary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                              color: AppColors.textPrimary,
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
                                  color: AppColors.textPrimary,
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
                    color: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
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
                          color: AppColors.textPrimary,
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
                                        : AppColors.textPrimary,
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
                        color: AppColors.textPrimary,
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

  Future<void> _saveItem() async {
    // Check which tab is active

    // Amazon tab (index 1) - items are added directly from browser
    if (_tabController.index == 1) {
      AppNotification.error(context, 'Use "Browse Amazon" to add items');
      return;
    }

    if (_tabController.index == 2) {
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
