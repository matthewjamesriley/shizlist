import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/list_item.dart';
import '../services/item_service.dart';
import '../services/image_upload_service.dart';
import '../services/amazon_service.dart';
import '../services/list_service.dart';
import '../services/user_settings_service.dart';
import 'app_button.dart';
import 'app_notification.dart';
import '../core/utils/price_formatter.dart';

/// Edit Item Sheet with tabs - can be shown from any context
class EditItemSheet extends StatefulWidget {
  final ListItem item;
  final String? listUid;
  final VoidCallback? onSaved;
  final VoidCallback? onDeleted;
  final VoidCallback? onListCoverChanged;

  const EditItemSheet({
    super.key,
    required this.item,
    this.listUid,
    this.onSaved,
    this.onDeleted,
    this.onListCoverChanged,
  });

  /// Show the edit item sheet as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required ListItem item,
    String? listUid,
    VoidCallback? onSaved,
    VoidCallback? onDeleted,
    VoidCallback? onListCoverChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Theme(
            // Use app theme to ensure consistent styling
            data: AppTheme.lightTheme,
            child: EditItemSheet(
              item: item,
              listUid: listUid,
              onSaved: onSaved,
              onDeleted: onDeleted,
              onListCoverChanged: onListCoverChanged,
            ),
          ),
    );
  }

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _urlController;

  late ItemCategory _selectedCategory;
  late ItemPriority _selectedPriority;
  bool _isLoading = false;

  // Image handling
  File? _selectedImage;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';
  String? _thumbnailUrl;
  String? _mainImageUrl;
  final ImageUploadService _imageService = ImageUploadService();

  // Amazon URL fetching
  bool _isFetchingAmazon = false;

  // Flag to prevent re-entrant URL extraction
  bool _isExtractingUrl = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _priceController = TextEditingController(
      text:
          widget.item.price != null
              ? widget.item.price!.toStringAsFixed(2)
              : '',
    );
    _urlController = TextEditingController(text: widget.item.retailerUrl ?? '');
    _selectedCategory = widget.item.category;
    _selectedPriority = widget.item.priority;
    _thumbnailUrl = widget.item.thumbnailUrl;
    _mainImageUrl = widget.item.mainImageUrl;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      AppNotification.error(context, 'Name is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      double? price;
      if (_priceController.text.isNotEmpty) {
        price = double.tryParse(_priceController.text.replaceAll(',', ''));
      }

      // Always pass description (empty string to clear)
      final description = _descriptionController.text.trim();
      final retailerUrl = _urlController.text.trim();

      await ItemService().updateItem(
        uid: widget.item.uid,
        name: _nameController.text.trim(),
        description: description.isEmpty ? '' : description,
        price: price,
        // Set currency from user settings when price is provided
        currency: price != null ? UserSettingsService().currencyCode : null,
        retailerUrl: retailerUrl.isEmpty ? '' : retailerUrl,
        category: _selectedCategory,
        priority: _selectedPriority,
        thumbnailUrl: _thumbnailUrl,
        mainImageUrl: _mainImageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
      }
    } catch (e) {
      debugPrint('Error updating item: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotification.error(context, 'Failed to update item: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _imageService.pickFromGallery();
    if (file != null) {
      await _processAndUploadImage(file);
    }
  }

  Future<void> _pickFromCamera() async {
    final file = await _imageService.pickFromCamera();
    if (file != null) {
      await _processAndUploadImage(file);
    }
  }

  Future<void> _processAndUploadImage(File file) async {
    setState(() {
      _selectedImage = file;
      _isUploadingImage = true;
      _uploadProgress = 0;
      _uploadStatus = 'Processing...';
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

      if (result != null && mounted) {
        setState(() {
          _thumbnailUrl = result.thumbnailUrl;
          _mainImageUrl = result.mainImageUrl;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _selectedImage = null;
        });
        AppNotification.error(context, 'Failed to upload image');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _thumbnailUrl = null;
      _mainImageUrl = null;
    });
  }

  Future<void> _setAsListCover() async {
    if (widget.listUid == null) return;

    final imageUrl = _mainImageUrl ?? _thumbnailUrl;
    if (imageUrl == null) return;

    try {
      await ListService().updateList(
        uid: widget.listUid!,
        coverImageUrl: imageUrl,
      );
      if (mounted) {
        AppNotification.success(context, 'Set as list cover');
        widget.onListCoverChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to set list cover');
      }
    }
  }

  void _showImagePreview() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, animation, secondaryAnimation) {
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
                            _selectedImage != null
                                ? Image.file(_selectedImage!)
                                : Image.network(
                                  _mainImageUrl ?? _thumbnailUrl!,
                                ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(ctx).padding.top + 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Edit item',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          GestureDetector(
                            onTap: _isLoading ? null : _handleSave,
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
                                        'Save',
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
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.titleMedium.copyWith(fontSize: 16),
                  tabs: const [Tab(text: 'Details'), Tab(text: 'Image & link')],
                ),
              ],
            ),
          ),

          // Tab content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDetailsTab(), _buildMediaTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
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
          // Name field
          Text('Name', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: AppTypography.bodyLarge,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Item name'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Description field
          Text('Description (optional)', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            style: AppTypography.bodyLarge,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Add a description'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Price and Priority row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceController,
                      style: AppTypography.bodyLarge,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [PriceInputFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Price',
                        prefixText: '${UserSettingsService().currencySymbol} ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Priority', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    Container(
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
                  ],
                ),
              ),
            ],
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
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? category.color : Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color:
                              isSelected ? category.color : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            category.icon,
                            size: 16,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),

          // Delete button (only show if onDeleted callback provided)
          if (widget.onDeleted != null)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDeleted!();
                },
                icon: PhosphorIcon(
                  PhosphorIcons.trash(),
                  color: AppColors.error,
                  size: 20,
                ),
                label: Text(
                  'Delete item',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
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
          // Image picker section
          _buildImagePicker(),
          const SizedBox(height: 24),

          // URL field
          Text('Item link (optional)', style: AppTypography.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _urlController,
            style: AppTypography.bodyLarge,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
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

          // Buttons row
          if (_urlController.text.trim().isNotEmpty)
            Row(
              children: [
                // Get product info button (for any URL)
                if (_urlController.text.trim().startsWith('http'))
                  Expanded(
                    child: AppButton.accent(
                      label:
                          _isFetchingAmazon
                              ? 'Fetching...'
                              : 'Get product info',
                      onPressed: !_isFetchingAmazon ? _fetchProductInfo : null,
                      isLoading: _isFetchingAmazon,
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
          const SizedBox(height: 16),
        ],
      ),
    );
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
        ] else if (_selectedImage != null || _thumbnailUrl != null) ...[
          // Selected/uploaded image preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _showImagePreview,
                    child: Container(
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
                                _thumbnailUrl!,
                                fit: BoxFit.cover,
                              ),
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
              // Set as list cover button
              if (widget.listUid != null &&
                  (_mainImageUrl != null || _thumbnailUrl != null)) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _setAsListCover,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.image(),
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Set as list cover',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ] else ...[
          // Image picker buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickFromGallery,
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
                  onTap: _pickFromCamera,
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

  Future<void> _fetchProductInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isFetchingAmazon = true);

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
            setState(() => _isFetchingAmazon = false);
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
            setState(() => _isFetchingAmazon = false);
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
                _selectedImage = null; // Clear any locally selected image
                _thumbnailUrl = uploadResult.thumbnailUrl;
                _mainImageUrl = uploadResult.mainImageUrl;
                _isUploadingImage = false;
                _isFetchingAmazon = false;
              });
              AppNotification.success(
                context,
                'Product info and image updated!',
              );
            } else {
              setState(() {
                _isUploadingImage = false;
                _isFetchingAmazon = false;
              });
              AppNotification.success(context, 'Product info updated!');
            }
          } catch (e) {
            // Image upload failed, but other info was still updated
            if (mounted) {
              setState(() {
                _isUploadingImage = false;
                _isFetchingAmazon = false;
              });
              AppNotification.success(
                context,
                'Product info updated! (Image could not be downloaded)',
              );
            }
          }
        } else {
          setState(() => _isFetchingAmazon = false);
          if (foundAnyInfo) {
            AppNotification.success(context, 'Product info updated!');
          } else {
            AppNotification.error(
              context,
              'Unable to fetch product info from this website',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingAmazon = false;
          _isUploadingImage = false;
        });
        AppNotification.error(context, 'Failed to fetch product info');
      }
    }
  }
}
