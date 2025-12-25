import 'package:flutter/foundation.dart';

/// Wish list visibility options
enum ListVisibility { private, friends, public }

ListVisibility _parseVisibility(String? value) {
  switch (value) {
    case 'public':
      return ListVisibility.public;
    case 'friends':
      return ListVisibility.friends;
    default:
      return ListVisibility.private;
  }
}

String _visibilityToString(ListVisibility visibility) {
  switch (visibility) {
    case ListVisibility.public:
      return 'public';
    case ListVisibility.friends:
      return 'friends';
    case ListVisibility.private:
      return 'private';
  }
}

/// Wish list model representing a user's list
@immutable
class WishList {
  final int id;
  final String uid;
  final String ownerId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final ListVisibility visibility;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int itemCount;
  final int claimedCount;
  final int purchasedCount;
  final DateTime? eventDate;
  final bool isRecurring;
  final bool notifyOnCommit;
  final bool notifyOnPurchase;

  const WishList({
    required this.id,
    required this.uid,
    required this.ownerId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.visibility,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.itemCount = 0,
    this.claimedCount = 0,
    this.purchasedCount = 0,
    this.eventDate,
    this.isRecurring = false,
    this.notifyOnCommit = true,
    this.notifyOnPurchase = true,
  });

  factory WishList.fromJson(Map<String, dynamic> json) {
    return WishList(
      id: json['id'] as int,
      uid: json['uid'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      visibility: _parseVisibility(json['visibility'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt:
          json['deleted_at'] != null
              ? DateTime.parse(json['deleted_at'] as String)
              : null,
      itemCount: json['item_count'] as int? ?? 0,
      claimedCount: json['claimed_count'] as int? ?? 0,
      purchasedCount: json['purchased_count'] as int? ?? 0,
      eventDate:
          json['event_date'] != null
              ? DateTime.parse(json['event_date'] as String)
              : null,
      isRecurring: json['is_recurring'] as bool? ?? false,
      notifyOnCommit: json['notify_on_commit'] as bool? ?? true,
      notifyOnPurchase: json['notify_on_purchase'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'visibility': _visibilityToString(visibility),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'event_date': eventDate?.toIso8601String().split('T').first,
      'is_recurring': isRecurring,
      'notify_on_commit': notifyOnCommit,
      'notify_on_purchase': notifyOnPurchase,
    };
  }

  /// Create a new list for insertion (without id and timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'uid': uid,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'visibility': _visibilityToString(visibility),
      'event_date': eventDate?.toIso8601String().split('T').first,
      'is_recurring': isRecurring,
      'notify_on_commit': notifyOnCommit,
      'notify_on_purchase': notifyOnPurchase,
    };
  }

  WishList copyWith({
    int? id,
    String? uid,
    String? ownerId,
    String? title,
    String? description,
    String? coverImageUrl,
    ListVisibility? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    int? itemCount,
    int? claimedCount,
    int? purchasedCount,
    DateTime? eventDate,
    bool? isRecurring,
    bool? notifyOnCommit,
    bool? notifyOnPurchase,
  }) {
    return WishList(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      itemCount: itemCount ?? this.itemCount,
      claimedCount: claimedCount ?? this.claimedCount,
      purchasedCount: purchasedCount ?? this.purchasedCount,
      eventDate: eventDate ?? this.eventDate,
      isRecurring: isRecurring ?? this.isRecurring,
      notifyOnCommit: notifyOnCommit ?? this.notifyOnCommit,
      notifyOnPurchase: notifyOnPurchase ?? this.notifyOnPurchase,
    );
  }

  /// Check if list is publicly accessible
  bool get isPublic => visibility == ListVisibility.public;

  /// Get the share URL for this list
  String get shareUrl => 'https://shizlist.co/list/$uid';

  /// Get progress percentage (claimed / total)
  double get progressPercentage {
    if (itemCount == 0) return 0;
    return claimedCount / itemCount;
  }

  /// Check if this list has an event date set
  bool get hasEventDate => eventDate != null;

  /// Get the next occurrence of the event date
  /// For recurring events, calculates next anniversary
  DateTime? get nextEventDate {
    if (eventDate == null) return null;
    if (!isRecurring) return eventDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate this year's occurrence
    var nextDate = DateTime(now.year, eventDate!.month, eventDate!.day);
    
    // If it's already passed this year, use next year
    if (nextDate.isBefore(today)) {
      nextDate = DateTime(now.year + 1, eventDate!.month, eventDate!.day);
    }
    
    return nextDate;
  }

  /// Get days until the next event date
  int? get daysUntilEvent {
    final next = nextEventDate;
    if (next == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return next.difference(today).inDays;
  }

  /// Check if the event date has passed (for non-recurring lists)
  bool get isExpired {
    if (eventDate == null || isRecurring) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDate!.isBefore(today);
  }

  /// Check if the event is coming up soon (within 30 days)
  bool get isUpcoming {
    final days = daysUntilEvent;
    return days != null && days >= 0 && days <= 30;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WishList && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'WishList(uid: $uid, title: $title)';
}
