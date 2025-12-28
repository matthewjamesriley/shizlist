import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
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

  const AmazonBrowserScreen({super.key, this.selectedList});

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

class _AmazonBrowserScreenState extends State<AmazonBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final AnimationController _buttonAnimController;
  late final Animation<double> _buttonSlideAnimation;
  late final Animation<double> _buttonFadeAnimation;

  bool _isLoading = true;
  bool _isOnProductPage = false;
  bool _isExtracting = false;
  bool _showAddButton = false;
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
    _buttonAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _buttonSlideAnimation = Tween<double>(begin: -40, end: 0).animate(
      CurvedAnimation(
        parent: _buttonAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _buttonFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _buttonAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _initWebView();
  }

  @override
  void dispose() {
    _buttonAnimController.dispose();
    super.dispose();
  }

  void _initWebView() {
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = url;
                  _showAddButton = false;
                });
                _buttonAnimController.reset();
                _checkIfProductPage(url, isPageFinished: false);
              },
              onPageFinished: (url) {
                setState(() {
                  _isLoading = false;
                  _currentUrl = url;
                });
                _checkIfProductPage(url, isPageFinished: true);
                _extractPageTitle();
                _hideAmazonButtons();
              },
              onNavigationRequest: (request) {
                // Allow all Amazon navigation
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(_amazonBaseUrl));
  }

  void _checkIfProductPage(String url, {required bool isPageFinished}) {
    // Check if URL contains product identifiers
    final isProduct =
        url.contains('/dp/') ||
        url.contains('/gp/product/') ||
        url.contains('/gp/aw/d/') ||
        RegExp(r'/[A-Z0-9]{10}(?:[/?]|$)').hasMatch(url);

    final isOnProduct = isProduct && AmazonService.isAmazonUrl(url);

    setState(() {
      _isOnProductPage = isOnProduct;
    });

    // Show button immediately when on product page
    if (isPageFinished && isOnProduct && _currentUrl != _lastAddedUrl) {
      if (mounted) {
        setState(() => _showAddButton = true);
        _buttonAnimController.forward();
      }
    }
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

  /// Hide Amazon buy/share buttons to encourage using our Add button
  Future<void> _hideAmazonButtons() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          var style = document.createElement('style');
          style.textContent = `
            /* Hide Add to Basket / Add to Cart buttons */
            #add-to-cart-button,
            #add-to-cart-button-ubb,
            .a-button-add-to-cart,
            [data-action="add-to-cart"],
            #addToCart,
            .addToCart,
            .a-button-input,
            #submit\\.add-to-cart,
            #submit\\.add-to-cart-announce,
            [name="submit.add-to-cart"],
            #add-to-cart-button-container,
            
            /* Hide Buy Now buttons */
            #buy-now-button,
            #buyNow,
            .buyNow,
            [data-action="buy-now"],
            #submit-button,
            #submit\\.buy-now,
            [name="submit.buy-now"],
            
            /* Hide Share buttons */
            #share-button,
            .share-button,
            [data-action="share"],
            #social-share,
            .social-share,
            #shareButtonLeft,
            .ssf-share-trigger,
            .share-trigger,
            #ssf-share-trigger,
            [class*="share-trigger"],
            [class*="ssf-share"],
            
            /* Hide Wishlist/Save buttons (Amazon's own) */
            #wishlist-button,
            .wishlist-button,
            [data-action="add-to-wishlist"],
            #add-to-wishlist-button,
            #add-to-wishlist-button-submit,
            
            /* Hide Like/Heart buttons */
            .heart-button,
            [data-action="like"],
            
            /* Hide Subscribe & Save */
            #snsAccordionRowMiddle,
            #sns-accordion,
            
            /* Mobile specific */
            .atc-button,
            .buybox-see-all-buying-choices,
            #mbc-action-panel-wrapper,
            
            /* Hide entire buy box buttons area */
            #desktop_buybox_feature_div .a-button,
            #mobile_buybox_feature_div .a-button,
            #buybox .a-button,
            .buying-options-slot .a-button
            
            { display: none !important; visibility: hidden !important; height: 0 !important; overflow: hidden !important; }
          `;
          document.head.appendChild(style);
        })();
      ''');
    } catch (e) {
      debugPrint('Error hiding Amazon buttons: $e');
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
          _showAddButton = false;
        });
        _buttonAnimController.reset();

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
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () async {
            if (await _controller.canGoBack()) {
              _controller.goBack();
            }
          },
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
            icon: PhosphorIcon(
              PhosphorIcons.arrowClockwise(),
              color: Colors.white,
            ),
            onPressed: () {
              setState(
                () => _lastAddedUrl = null,
              ); // Allow re-adding after refresh
              _controller.reload();
            },
          ),
          // Close button
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.x(), color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
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

          // Touch-blocking overlay behind the button area (uses PointerInterceptor for WebView)
          if (_showAddButton && _currentUrl != _lastAddedUrl)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PointerInterceptor(
                child: Container(
                  height: MediaQuery.of(context).padding.bottom + 100,
                  color: Colors.transparent,
                ),
              ),
            ),

          // Floating "Add to ShizList" button (hide if already added this product)
          if (_showAddButton && _currentUrl != _lastAddedUrl)
            AnimatedBuilder(
              animation: _buttonAnimController,
              builder: (context, child) {
                return Positioned(
                  bottom:
                      MediaQuery.of(context).padding.bottom +
                      16 +
                      _buttonSlideAnimation.value,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    ignoring: _buttonFadeAnimation.value < 0.9,
                    child: Opacity(
                      opacity: _buttonFadeAnimation.value,
                      child: PointerInterceptor(child: child!),
                    ),
                  ),
                );
              },
              child: _buildAddButton(),
            ),

          // Footer hint when not on product page
          if (!_showAddButton || _currentUrl == _lastAddedUrl)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PointerInterceptor(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    0 + MediaQuery.of(context).padding.bottom,
                  ),
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Text(
                    'Browse to a product page to add an item to your \'${widget.selectedList?.title ?? 'list'}\' list',
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.black, width: 4),
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
                    'Adding product to list...',
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
    );
  }
}
