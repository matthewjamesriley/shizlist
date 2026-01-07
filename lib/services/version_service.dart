import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to check for app updates
class VersionService {
  static const String _iosAppId = '6756820711';
  static const String _androidPackage = 'co.shizlist.app';
  static const String _lastCheckKey = 'last_version_check';
  static const String _skippedVersionKey = 'skipped_version';
  
  /// Set to true to force show update dialog for testing
  static const bool _forceShowForTesting = false;
  
  /// Check if a new version is available
  /// Returns the new version string if available, null otherwise
  static Future<String?> checkForUpdate() async {
    // For testing: force show dialog with fake version
    if (_forceShowForTesting) {
      debugPrint('VersionService: Force showing update dialog for testing');
      return '99.0.0'; // Fake newer version for testing
    }
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      String? latestVersion;
      
      if (Platform.isIOS) {
        latestVersion = await _getIOSLatestVersion();
      } else if (Platform.isAndroid) {
        latestVersion = await _getAndroidLatestVersion();
      }
      
      if (latestVersion == null) return null;
      
      // Compare versions
      if (_isNewerVersion(latestVersion, currentVersion)) {
        return latestVersion;
      }
      
      return null;
    } catch (e) {
      debugPrint('Version check failed: $e');
      return null;
    }
  }
  
  /// Get iOS latest version from App Store
  static Future<String?> _getIOSLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=$_iosAppId&country=gb'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['resultCount'] > 0) {
          return json['results'][0]['version'] as String?;
        }
      }
    } catch (e) {
      debugPrint('iOS version check failed: $e');
    }
    return null;
  }
  
  /// Get Android latest version from Play Store
  static Future<String?> _getAndroidLatestVersion() async {
    try {
      // Try to fetch from Play Store page
      final response = await http.get(
        Uri.parse('https://play.google.com/store/apps/details?id=$_androidPackage&hl=en'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Parse version from the page - look for the version pattern
        final regex = RegExp(r'\[\[\["(\d+\.\d+\.\d+)"\]\]');
        final match = regex.firstMatch(response.body);
        if (match != null) {
          return match.group(1);
        }
        
        // Alternative pattern
        final altRegex = RegExp(r'Current Version.+?>([\d.]+)<');
        final altMatch = altRegex.firstMatch(response.body);
        if (altMatch != null) {
          return altMatch.group(1);
        }
      }
    } catch (e) {
      debugPrint('Android version check failed: $e');
    }
    return null;
  }
  
  /// Compare version strings (e.g., "1.0.34" > "1.0.33")
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      
      // Pad with zeros if needed
      while (latestParts.length < 3) latestParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);
      
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if we should show the update dialog (not too frequently)
  static Future<bool> shouldShowUpdateDialog(String newVersion) async {
    // For testing: always show
    if (_forceShowForTesting) {
      return true;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user skipped this version
      final skippedVersion = prefs.getString(_skippedVersionKey);
      if (skippedVersion == newVersion) {
        return false;
      }
      
      // Check when we last showed the dialog (don't show more than once per day)
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneDayMs = 24 * 60 * 60 * 1000;
      
      if (now - lastCheck < oneDayMs) {
        return false;
      }
      
      // Update last check time
      await prefs.setInt(_lastCheckKey, now);
      return true;
    } catch (e) {
      return true;
    }
  }
  
  /// Mark a version as skipped (user chose "Later")
  static Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, version);
    } catch (e) {
      debugPrint('Failed to save skipped version: $e');
    }
  }
  
  /// Get the store URL for the current platform
  static String getStoreUrl() {
    if (Platform.isIOS) {
      return 'https://apps.apple.com/gb/app/shizlist/id$_iosAppId';
    } else {
      return 'https://play.google.com/store/apps/details?id=$_androidPackage';
    }
  }
}

