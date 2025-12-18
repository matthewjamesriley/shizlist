import 'package:flutter/foundation.dart';
import '../models/currency.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Service for managing user settings, including currency preference
class UserSettingsService extends ChangeNotifier {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  final AuthService _authService = AuthService();
  
  UserProfile? _userProfile;
  Currency _currency = Currency.defaultCurrency;
  bool _isLoading = false;

  /// Current user's currency
  Currency get currency => _currency;

  /// Current user's currency symbol
  String get currencySymbol => _currency.symbol;

  /// Current user's currency code
  String get currencyCode => _currency.code;

  /// Whether settings are loading
  bool get isLoading => _isLoading;

  /// Current user profile
  UserProfile? get userProfile => _userProfile;

  /// Load user settings from the database
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _authService.getCurrentUserProfile();
      if (_userProfile != null) {
        _currency = Currency.fromCode(_userProfile!.currencyCode);
      }
    } catch (e) {
      debugPrint('Error loading user settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user's currency preference
  Future<void> updateCurrency(String currencyCode) async {
    try {
      _userProfile = await _authService.updateUserCurrency(currencyCode);
      _currency = Currency.fromCode(currencyCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating currency: $e');
      rethrow;
    }
  }

  /// Format a price using the user's currency
  String formatPrice(double amount) {
    return _currency.format(amount);
  }

  /// Clear settings (on logout)
  void clear() {
    _userProfile = null;
    _currency = Currency.defaultCurrency;
    notifyListeners();
  }
}

