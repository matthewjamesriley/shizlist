import 'package:flutter/foundation.dart';

/// Wish list visibility options
enum ListVisibility { private, public }

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
  });

  factory WishList.fromJson(Map<String, dynamic> json) {
    return WishList(
      id: json['id'] as int,
      uid: json['uid'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      visibility: json['visibility'] == 'public'
          ? ListVisibility.public
          : ListVisibility.private,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      itemCount: json['item_count'] as int? ?? 0,
      claimedCount: json['claimed_count'] as int? ?? 0,
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
      'visibility': visibility == ListVisibility.public ? 'public' : 'private',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
      'visibility': visibility == ListVisibility.public ? 'public' : 'private',
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
    );
  }

  /// Check if list is publicly accessible
  bool get isPublic => visibility == ListVisibility.public;

  /// Get the share URL for this list
  String get shareUrl => 'https://shizlist.app/list/$uid';

  /// Get progress percentage (claimed / total)
  double get progressPercentage {
    if (itemCount == 0) return 0;
    return claimedCount / itemCount;
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


