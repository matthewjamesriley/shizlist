/// ShizList App Constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'ShizList';
  static const String appTagline = 'Share the stuff you love';
  static const String appVersion = '1.0.0';

  // Image Sizes
  static const int thumbnailSize = 150;
  static const int mainImageSize = 900;

  // Categories
  static const List<String> categories = [
    'Stuff',
    'Events',
    'Trips',
    'Homemade',
    'Meals',
    'Other',
  ];

  // Message Scopes
  static const List<String> messageScopes = [
    'All Gifters',
    'Everyone',
    'Creator Only',
    'Selected Gifters',
  ];

  // List Visibility
  static const String visibilityPrivate = 'private';
  static const String visibilityPublic = 'public';

  // Claim Status
  static const String claimStatusActive = 'active';
  static const String claimStatusExpired = 'expired';
  static const String claimStatusPurchased = 'purchased';

  // Storage Buckets
  static const String profileImagesBucket = 'profile_images';
  static const String itemImagesBucket = 'item_images';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxSearchResults = 50;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;
  static const int maxListItems = 200;
}
