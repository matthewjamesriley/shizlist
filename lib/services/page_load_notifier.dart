import 'package:flutter/foundation.dart';

/// Notifier for page load completion events
class PageLoadNotifier extends ChangeNotifier {
  static final PageLoadNotifier _instance = PageLoadNotifier._internal();
  factory PageLoadNotifier() => _instance;
  PageLoadNotifier._internal();

  bool _listsPageLoaded = false;

  bool get listsPageLoaded => _listsPageLoaded;

  void notifyListsPageLoaded() {
    _listsPageLoaded = true;
    notifyListeners();
  }

  void resetListsPageLoaded() {
    _listsPageLoaded = false;
  }
}

