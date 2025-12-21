import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/list_item.dart';
import '../models/wish_list.dart';
import '../services/amazon_service.dart';
import '../services/item_service.dart';
import '../services/image_upload_service.dart';
import '../services/lists_notifier.dart';
import '../services/user_settings_service.dart';
import 'app_notification.dart';

/// Result returned when user adds a product from the Amazon browser
class AmazonBrowserResult {
  final String? title;
  final String? price;
  final String? imageUrl;
  final String? affiliateUrl;
  final String? asin;

  AmazonBrowserResult({
    this.title,
    this.price,
    this.imageUrl,
    this.affiliateUrl,
    this.asin,
  });
}

/// In-app Amazon browser with floating "Add to ShizList" button
class AmazonBrowserScreen extends StatefulWidget {
  final WishList? selectedList;

  const AmazonBrowserScreen({
    super.key,
    this.selectedList,
  });

  /// Show the Amazon browser as a full-screen modal
  static Future<AmazonBrowserResult?> show(
    BuildContext context, {
    WishList? selectedList,
  }) {
    return Navigator.of(context).push<AmazonBrowserResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AmazonBrowserScreen(selectedList: selectedList),
      ),
    );
  }

  @override
  State<AmazonBrowserScreen> createState() => _AmazonBrowserScreenState();
}

class _AmazonBrowserScreenState extends State<AmazonBrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isOnProductPage = false;
  bool _isExtracting = false;
  String _currentUrl = '';
  String? _pageTitle;
  String? _lastAddedUrl; // Track URL of last added product

  // Detect user's likely Amazon domain based on locale
  String get _amazonBaseUrl {
    // Could be extended to detect user's region
    return 'https://www.amazon.co.uk';
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            _checkIfProductPage(url);
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _checkIfProductPage(url);
            _extractPageTitle();
          },
          onNavigationRequest: (request) {
            // Allow all Amazon navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_amazonBaseUrl));
  }

  void _checkIfProductPage(String url) {
    // Check if URL contains product identifiers
    final isProduct = url.contains('/dp/') ||
        url.contains('/gp/product/') ||
        url.contains('/gp/aw/d/') ||
        RegExp(r'/[A-Z0-9]{10}(?:[/?]|$)').hasMatch(url);

    setState(() {
      _isOnProductPage = isProduct && AmazonService.isAmazonUrl(url);
    });
  }

  Future<void> _extractPageTitle() async {
    try {
      final title = await _controller.runJavaScriptReturningResult(
        'document.title',
      );
      setState(() {
        _pageTitle = title.toString().replaceAll('"', '');
      });
    } catch (e) {
      debugPrint('Error extracting title: $e');
    }
  }

  Future<void> _addProduct() async {
    if (_currentUrl.isEmpty) return;

    if (widget.selectedList == null) {
      AppNotification.error(context, 'No list selected');
      return;
    }

    setState(() => _isExtracting = true);

    try {
      // Extract product info using existing service
      final info = await AmazonService.fetchProductInfo(_currentUrl);

      // Download and upload image if available
      String? thumbnailUrl;
      String? mainImageUrl;
      
      final imageUrl = info['imageUrl'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final uploadResult = await ImageUploadService().downloadAndUpload(
            imageUrl,
            onProgress: (progress, status) {
              // Could show progress here if needed
            },
          );
          if (uploadResult != null) {
            thumbnailUrl = uploadResult.thumbnailUrl;
            mainImageUrl = uploadResult.mainImageUrl;
          }
        } catch (e) {
          // Image upload failed, continue without image
          debugPrint('Image upload failed: $e');
        }
      }

      // Parse price
      double? price;
      final priceStr = info['price'];
      if (priceStr != null && priceStr.isNotEmpty) {
        price = double.tryParse(priceStr.replaceAll(',', ''));
      }

      // Create the item
      await ItemService().createItem(
        listId: widget.selectedList!.id,
        name: info['title'] ?? 'Amazon Product',
        price: price,
        currency: UserSettingsService().currencyCode,
        retailerUrl: info['affiliateUrl'],
        category: ItemCategory.stuff,
        priority: ItemPriority.none,
        thumbnailUrl: thumbnailUrl,
        mainImageUrl: mainImageUrl,
      );

      // Notify listeners that item count changed
      ListsNotifier().notifyItemCountChanged();

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _lastAddedUrl = _currentUrl; // Hide button for this product
        });
        
        // Show success notification - stay on browser
        AppNotification.success(
          context,
          'Added to "${widget.selectedList!.title}"',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        AppNotification.error(context, 'Failed to add product');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.x(), color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse Amazon',
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_pageTitle != null && _pageTitle!.isNotEmpty)
              Text(
                _pageTitle!.length > 40
                    ? '${_pageTitle!.substring(0, 40)}...'
                    : _pageTitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.arrowClockwise(), color: Colors.white),
            onPressed: () {
              setState(() => _lastAddedUrl = null); // Allow re-adding after refresh
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),

          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
              ),
            ),

          // Floating "Add to ShizList" button (hide if already added this product)
          if (_isOnProductPage && _currentUrl != _lastAddedUrl)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _buildAddButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return AnimatedOpacity(
      opacity: _isOnProductPage ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: _isExtracting ? null : _addProduct,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isExtracting) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Getting product info...',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ] else ...[
                    PhosphorIcon(
                      PhosphorIcons.plus(),
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.selectedList != null
                            ? 'Add to "${widget.selectedList!.title}"'
                            : 'Add to ShizList',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

