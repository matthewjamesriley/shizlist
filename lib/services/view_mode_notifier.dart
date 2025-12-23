import 'package:flutter/foundation.dart';

/// Notifier for list view mode (compact vs cards)
class ViewModeNotifier extends ChangeNotifier {
  static final ViewModeNotifier _instance = ViewModeNotifier._internal();
  factory ViewModeNotifier() => _instance;
  ViewModeNotifier._internal();

  bool _isCompactView = false;

  bool get isCompactView => _isCompactView;

  void toggle() {
    _isCompactView = !_isCompactView;
    notifyListeners();
  }

  void setCompact(bool value) {
    if (_isCompactView != value) {
      _isCompactView = value;
      notifyListeners();
    }
  }
}

