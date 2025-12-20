import 'package:http/http.dart' as http;

/// Service for handling Amazon product URLs and affiliate links
class AmazonService {
  // Your Amazon Associates affiliate tag
  static const String affiliateTag = 'cosyhomefinds-21';

  /// Extract ASIN from various Amazon URL formats
  /// Returns null if no valid ASIN found
  static String? extractAsin(String url) {
    if (url.isEmpty) return null;

    url = url.trim();

    final patterns = [
      RegExp(r'/dp/([A-Z0-9]{10})', caseSensitive: false),
      RegExp(r'/gp/product/([A-Z0-9]{10})', caseSensitive: false),
      RegExp(r'/gp/aw/d/([A-Z0-9]{10})', caseSensitive: false),
      RegExp(r'/product/([A-Z0-9]{10})', caseSensitive: false),
      RegExp(r'amazon\.[a-z.]+/([A-Z0-9]{10})(?:/|\?|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.toUpperCase();
      }
    }

    return null;
  }

  /// Check if a URL is an Amazon URL (any type)
  static bool isAmazonUrl(String url) {
    if (url.isEmpty) return false;
    url = url.toLowerCase();
    return url.contains('amazon.') || url.contains('amzn.');
  }

  /// Check if URL is a search results page (not a product)
  static bool isSearchUrl(String url) {
    if (url.isEmpty) return false;
    url = url.toLowerCase();
    // Search URLs contain /s? or /s/ patterns
    return url.contains('/s?') ||
        url.contains('/s/') ||
        url.contains('field-keywords=') ||
        url.contains('/gp/search');
  }

  /// Check if URL is a valid product URL (has ASIN)
  static bool isProductUrl(String url) {
    return isAmazonUrl(url) && !isSearchUrl(url) && extractAsin(url) != null;
  }

  /// Generate an affiliate link from an ASIN
  static String generateAffiliateLink(String asin, {String? domain}) {
    domain ??= 'amazon.com';
    return 'https://www.$domain/dp/$asin?tag=$affiliateTag';
  }

  /// Convert any Amazon URL to an affiliate link
  static String? convertToAffiliateLink(String url) {
    final asin = extractAsin(url);
    if (asin == null) return null;

    String domain = 'amazon.com';
    final domainMatch = RegExp(
      r'amazon\.([a-z.]+)',
    ).firstMatch(url.toLowerCase());
    if (domainMatch != null) {
      domain = 'amazon.${domainMatch.group(1)}';
    }

    return generateAffiliateLink(asin, domain: domain);
  }

  /// Fetch product info from Amazon URL
  /// Attempts to scrape title, price, and image from the page
  static Future<Map<String, String?>> fetchProductInfo(String url) async {
    final result = <String, String?>{
      'asin': null,
      'title': null,
      'price': null,
      'imageUrl': null,
      'affiliateUrl': null,
    };

    final asin = extractAsin(url);
    if (asin == null) return result;

    result['asin'] = asin;
    result['affiliateUrl'] = convertToAffiliateLink(url);

    // Extract domain from URL
    String domain = 'amazon.co.uk';
    final domainMatch = RegExp(
      r'amazon\.([a-z.]+)',
    ).firstMatch(url.toLowerCase());
    if (domainMatch != null) {
      domain = 'amazon.${domainMatch.group(1)}';
    }

    // Try multiple URL formats to get the best content
    final urlsToTry = [
      'https://www.$domain/dp/$asin', // Clean desktop URL
      'https://www.$domain/gp/aw/d/$asin', // Mobile URL (often has cleaner HTML)
      url, // Original URL as fallback
    ];

    String? body;
    for (final tryUrl in urlsToTry) {
      try {
        final response = await http
            .get(
              Uri.parse(tryUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
                'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
                'Accept-Encoding': 'identity',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && response.body.length > 5000) {
          body = response.body;

          // Try to extract price from this response
          final price = _extractPrice(body);
          if (price != null) {
            // Found a price, use this body
            result['title'] = _extractTitle(body);
            result['price'] = price;
            result['imageUrl'] = _extractImage(body);
            break;
          }

          // No price found, try next URL
          // But keep this body as fallback if we don't find better
          if (result['title'] == null) {
            result['title'] = _extractTitle(body);
            result['imageUrl'] = _extractImage(body);
          }
        }
      } catch (e) {
        // Continue to next URL
      }
    }

    // Fallback: if no title found, try URL slug
    if (result['title'] == null || result['title']!.isEmpty) {
      result['title'] = _extractTitleFromUrl(url);
    }

    return result;
  }

  /// Extract title from HTML
  static String? _extractTitle(String html) {
    // Try og:title meta tag with double quotes (property first)
    var match = RegExp(
      r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _decodeHtml(match.group(1) ?? '');
    }

    // Try og:title with content before property (double quotes)
    match = RegExp(
      r'<meta[^>]+content="([^"]+)"[^>]+property="og:title"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _decodeHtml(match.group(1) ?? '');
    }

    // Try og:title meta tag with single quotes
    match = RegExp(
      r"<meta[^>]+property='og:title'[^>]+content='([^']+)'",
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _decodeHtml(match.group(1) ?? '');
    }

    // Try twitter:title meta tag
    match = RegExp(
      r'<meta[^>]+name="twitter:title"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _decodeHtml(match.group(1) ?? '');
    }

    // Try productTitle span
    match = RegExp(
      r'id="productTitle"[^>]*>\s*([^<]+)<',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _decodeHtml(match.group(1)?.trim() ?? '');
    }

    // Try title tag
    match = RegExp(
      r'<title>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      var title = _decodeHtml(match.group(1) ?? '');
      // Remove common Amazon suffixes
      title = title.replaceAll(
        RegExp(r'\s*[:\-|].*Amazon.*$', caseSensitive: false),
        '',
      );
      return title.trim();
    }

    return null;
  }

  /// Extract price from HTML
  static String? _extractPrice(String html) {
    // Decode HTML entities first for price symbols
    final decodedHtml = html
        .replaceAll('&pound;', '£')
        .replaceAll('&#163;', '£')
        .replaceAll('&euro;', '€')
        .replaceAll('&#8364;', '€')
        .replaceAll('&dollar;', '\$')
        .replaceAll('&#36;', '\$');

    // Try various price patterns (order matters - most specific first)

    // Pattern 1: a-price-whole and a-price-fraction (most reliable)
    var match = RegExp(
      r'class="a-price-whole">([0-9,]+)</span>.*?class="a-price-fraction">([0-9]+)</span>',
      dotAll: true,
    ).firstMatch(decodedHtml);
    if (match != null) {
      final whole = match.group(1)?.replaceAll(',', '') ?? '';
      final fraction = match.group(2) ?? '00';
      return '$whole.$fraction';
    }

    // Pattern 2: a-offscreen price (accessibility price, very reliable)
    match = RegExp(
      r'class="a-offscreen">\s*[£\$€]?\s*([0-9,]+\.?[0-9]*)\s*</span>',
      caseSensitive: false,
    ).firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1)?.replaceAll(',', '');
    }

    // Pattern 3: Price with currency symbol directly (e.g., £5.05)
    match = RegExp(r'[£\$€]\s*([0-9]+\.[0-9]{2})\b').firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1);
    }

    // Pattern 4: Price in JSON data (priceAmount or similar)
    match = RegExp(
      r'"priceAmount"\s*:\s*"?([0-9]+\.?[0-9]*)"?',
      caseSensitive: false,
    ).firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1);
    }

    // Pattern 5: Generic "price" in JSON
    match = RegExp(
      r'"price"\s*:\s*"?([0-9]+\.?[0-9]*)"?',
      caseSensitive: false,
    ).firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1);
    }

    // Pattern 6: buyingPrice patterns
    match = RegExp(
      r'"buyingPrice"\s*:\s*([0-9]+\.?[0-9]*)',
      caseSensitive: false,
    ).firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1);
    }

    // Pattern 7: Whole number price with currency (no decimals)
    match = RegExp(r'[£\$€]\s*([0-9]+)\b(?!\.[0-9])').firstMatch(decodedHtml);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  /// Extract image from HTML
  static String? _extractImage(String html) {
    // Try og:image meta tag with double quotes (property first)
    var match = RegExp(
      r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try og:image with content before property (double quotes)
    match = RegExp(
      r'<meta[^>]+content="([^"]+)"[^>]+property="og:image"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try og:image meta tag with single quotes
    match = RegExp(
      r"<meta[^>]+property='og:image'[^>]+content='([^']+)'",
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try twitter:image meta tag
    match = RegExp(
      r'<meta[^>]+name="twitter:image"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try landingImage
    match = RegExp(
      r'id="landingImage"[^>]*src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try main-image-container img
    match = RegExp(
      r'id="main-image-container"[^>]*>.*?<img[^>]+src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try imgBlkFront (alternate image id)
    match = RegExp(
      r'id="imgBlkFront"[^>]*src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try hiRes image from data-old-hires attribute
    match = RegExp(
      r'data-old-hires="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try imageGalleryData JSON
    match = RegExp(
      r'"hiRes"\s*:\s*"(https://[^"]+images/I/[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try colorImages JSON (common in product pages)
    match = RegExp(
      r'"large"\s*:\s*"(https://[^"]+images/I/[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try data-a-dynamic-image JSON
    match = RegExp(
      r'data-a-dynamic-image="\{&quot;([^&]+)&quot;',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(1));
    }

    // Try any Amazon media image URL in the HTML (common pattern)
    match = RegExp(
      r'https://m\.media-amazon\.com/images/I/[A-Za-z0-9._%-]+\.jpg',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(0));
    }

    // Try images-amazon.com pattern
    match = RegExp(
      r'https://images-[a-z]+\.ssl-images-amazon\.com/images/I/[A-Za-z0-9._%-]+\.jpg',
      caseSensitive: false,
    ).firstMatch(html);
    if (match != null) {
      return _normalizeImageUrl(match.group(0));
    }

    return null;
  }

  /// Normalize Amazon image URL to get a good quality version
  static String? _normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Decode HTML entities
    url = _decodeHtml(url);

    // If it's an Amazon image, try to get a larger version
    if (url.contains('images/I/') || url.contains('images-amazon')) {
      // Remove size suffixes and request a larger image
      // Patterns like ._SX300_ or ._SL500_ or ._AC_SY400_
      url = url.replaceAll(RegExp(r'\._[A-Za-z0-9,_]+_\.'), '._SL500_.');
    }

    return url;
  }

  /// Extract title from URL slug
  static String? _extractTitleFromUrl(String url) {
    final slugMatch = RegExp(
      r'/([^/]+)/dp/',
      caseSensitive: false,
    ).firstMatch(url);
    if (slugMatch != null) {
      final slug = slugMatch.group(1);
      if (slug != null && slug.isNotEmpty && slug != 'dp') {
        final title =
            slug.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        return title
            .split(' ')
            .map(
              (word) =>
                  word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                      : word,
            )
            .join(' ');
      }
    }
    return null;
  }

  /// Decode HTML entities
  static String _decodeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
