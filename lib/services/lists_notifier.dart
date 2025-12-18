import 'package:flutter/foundation.dart';
import '../models/wish_list.dart';

/// Simple notifier to communicate list changes across the app
class ListsNotifier extends ChangeNotifier {
  static final ListsNotifier _instance = ListsNotifier._internal();
  factory ListsNotifier() => _instance;
  ListsNotifier._internal();

  WishList? _lastAddedList;
  WishList? get lastAddedList => _lastAddedList;

  void notifyListAdded(WishList list) {
    _lastAddedList = list;
    notifyListeners();
  }

  void clearLastAdded() {
    _lastAddedList = null;
  }
}


