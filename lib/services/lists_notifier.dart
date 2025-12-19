import 'package:flutter/foundation.dart';
import '../models/wish_list.dart';

/// Simple notifier to communicate list changes across the app
class ListsNotifier extends ChangeNotifier {
  static final ListsNotifier _instance = ListsNotifier._internal();
  factory ListsNotifier() => _instance;
  ListsNotifier._internal();

  WishList? _lastAddedList;
  WishList? get lastAddedList => _lastAddedList;

  String? _lastDeletedListUid;
  String? get lastDeletedListUid => _lastDeletedListUid;

  bool _itemCountChanged = false;
  bool get itemCountChanged => _itemCountChanged;

  void notifyListAdded(WishList list) {
    _lastAddedList = list;
    notifyListeners();
  }

  void clearLastAdded() {
    _lastAddedList = null;
  }

  void notifyListDeleted(String uid) {
    _lastDeletedListUid = uid;
    notifyListeners();
  }

  void clearLastDeleted() {
    _lastDeletedListUid = null;
  }

  void notifyItemCountChanged() {
    _itemCountChanged = true;
    notifyListeners();
  }

  void clearItemCountChanged() {
    _itemCountChanged = false;
  }
}


