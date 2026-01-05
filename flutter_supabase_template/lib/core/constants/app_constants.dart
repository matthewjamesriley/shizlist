/// App Constants - Customize for your app
class AppConstants {
  AppConstants._();

  // ============================================
  // TODO: Update these for your app
  // ============================================
  
  // App Info
  static const String appName = 'My App';
  static const String appTagline = 'Your tagline here';
  static const String appVersion = '1.0.0';

  // ============================================
  // Common constants (usually don't need changing)
  // ============================================

  // Image Sizes
  static const int thumbnailSize = 150;
  static const int mainImageSize = 900;

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
}




