import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import 'currency.dart';

/// Item category enum
enum ItemCategory {
  stuff,
  events,
  trips,
  crafted,
  meals,
  other;

  String get displayName {
    switch (this) {
      case ItemCategory.stuff:
        return 'Stuff';
      case ItemCategory.events:
        return 'Events';
      case ItemCategory.trips:
        return 'Trips';
      case ItemCategory.crafted:
        return 'Crafted';
      case ItemCategory.meals:
        return 'Meals';
      case ItemCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case ItemCategory.stuff:
        return AppColors.categoryStuff;
      case ItemCategory.events:
        return AppColors.categoryEvents;
      case ItemCategory.trips:
        return AppColors.categoryTrips;
      case ItemCategory.crafted:
        return AppColors.categoryCrafted;
      case ItemCategory.meals:
        return AppColors.categoryMeals;
      case ItemCategory.other:
        return AppColors.categoryOther;
    }
  }

  IconData get icon {
    switch (this) {
      case ItemCategory.stuff:
        return Icons.shopping_bag_outlined;
      case ItemCategory.events:
        return Icons.event_outlined;
      case ItemCategory.trips:
        return Icons.flight_outlined;
      case ItemCategory.crafted:
        return Icons.handyman_outlined;
      case ItemCategory.meals:
        return Icons.restaurant_outlined;
      case ItemCategory.other:
        return Icons.more_horiz;
    }
  }

  static ItemCategory fromString(String value) {
    // Handle legacy 'homemade' value -> now 'crafted'
    if (value.toLowerCase() == 'homemade') {
      return ItemCategory.crafted;
    }
    return ItemCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ItemCategory.other,
    );
  }
}

/// Item priority enum
enum ItemPriority {
  none,
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case ItemPriority.none:
        return 'No priority';
      case ItemPriority.low:
        return 'Into it';
      case ItemPriority.medium:
        return 'Love it';
      case ItemPriority.high:
        return 'Must have';
    }
  }

  Color get color {
    switch (this) {
      case ItemPriority.none:
        return const Color(0xFF9E9E9E); // Grey
      case ItemPriority.low:
        return const Color(0xFF2196F3); // Blue
      case ItemPriority.medium:
        return const Color(0xFFE53935); // Red
      case ItemPriority.high:
        return const Color.fromARGB(255, 239, 153, 16); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case ItemPriority.none:
        return PhosphorIcons.circle();
      case ItemPriority.low:
        return PhosphorIcons.thumbsUp(PhosphorIconsStyle.fill);
      case ItemPriority.medium:
        return PhosphorIcons.heartStraight(PhosphorIconsStyle.fill);
      case ItemPriority.high:
        return PhosphorIcons.star(PhosphorIconsStyle.fill);
    }
  }

  static ItemPriority fromString(String value) {
    return ItemPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ItemPriority.none,
    );
  }
}

/// List item model representing a wish list item
@immutable
class ListItem {
  final int id;
  final String uid;
  final int listId;
  final String name;
  final String? description;
  final double? price;
  final String? currency;
  final String? thumbnailUrl;
  final String? mainImageUrl;
  final String? retailerUrl;
  final String? amazonAsin;
  final ItemCategory category;
  final ItemPriority priority;
  final int quantity;
  final bool isClaimed;
  final String? claimedByUserId;
  final String? claimedByDisplayName;
  final String? claimedByAvatarUrl;
  final String? commitStatus; // 'active', 'purchased', 'expired', 'cancelled'
  final String? commitNote;
  final String? commitUid;
  final DateTime? claimedAt;
  final DateTime? claimExpiresAt;
  final DateTime? purchasedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ListItem({
    required this.id,
    required this.uid,
    required this.listId,
    required this.name,
    this.description,
    this.price,
    this.currency = 'USD',
    this.thumbnailUrl,
    this.mainImageUrl,
    this.retailerUrl,
    this.amazonAsin,
    required this.category,
    this.priority = ItemPriority.none,
    this.quantity = 1,
    this.isClaimed = false,
    this.claimedByUserId,
    this.claimedByDisplayName,
    this.claimedByAvatarUrl,
    this.commitStatus,
    this.commitNote,
    this.commitUid,
    this.claimedAt,
    this.claimExpiresAt,
    this.purchasedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'] as int,
      uid: json['uid'] as String,
      listId: json['list_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      currency: json['currency'] as String? ?? 'USD',
      thumbnailUrl: json['thumbnail_url'] as String?,
      mainImageUrl: json['main_image_url'] as String?,
      retailerUrl: json['retailer_url'] as String?,
      amazonAsin: json['amazon_asin'] as String?,
      category: ItemCategory.fromString(json['category'] as String? ?? 'other'),
      priority: ItemPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      quantity: json['quantity'] as int? ?? 1,
      isClaimed: json['is_claimed'] as bool? ?? false,
      claimedByUserId: json['claimed_by_user_id'] as String?,
      claimedByDisplayName: json['claimed_by_display_name'] as String?,
      claimedByAvatarUrl: json['claimed_by_avatar_url'] as String?,
      commitStatus: json['commit_status'] as String?,
      commitNote: json['commit_note'] as String?,
      commitUid: json['commit_uid'] as String?,
      claimedAt:
          json['claimed_at'] != null
              ? DateTime.parse(json['claimed_at'] as String)
              : null,
      claimExpiresAt:
          json['claim_expires_at'] != null
              ? DateTime.parse(json['claim_expires_at'] as String)
              : null,
      purchasedAt:
          json['purchased_at'] != null
              ? DateTime.parse(json['purchased_at'] as String)
              : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'list_id': listId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'thumbnail_url': thumbnailUrl,
      'main_image_url': mainImageUrl,
      'retailer_url': retailerUrl,
      'amazon_asin': amazonAsin,
      'category': category.name,
      'priority': priority.name,
      'quantity': quantity,
      'is_claimed': isClaimed,
      'claimed_by_user_id': claimedByUserId,
      'claimed_by_display_name': claimedByDisplayName,
      'claimed_by_avatar_url': claimedByAvatarUrl,
      'commit_status': commitStatus,
      'commit_note': commitNote,
      'commit_uid': commitUid,
      'claimed_at': claimedAt?.toIso8601String(),
      'claim_expires_at': claimExpiresAt?.toIso8601String(),
      'purchased_at': purchasedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a new item for insertion (without id and timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'uid': uid,
      'list_id': listId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'thumbnail_url': thumbnailUrl,
      'main_image_url': mainImageUrl,
      'retailer_url': retailerUrl,
      'amazon_asin': amazonAsin,
      'category': category.name,
      'priority': priority.name,
      'quantity': quantity,
    };
  }

  ListItem copyWith({
    int? id,
    String? uid,
    int? listId,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? thumbnailUrl,
    String? mainImageUrl,
    String? retailerUrl,
    String? amazonAsin,
    ItemCategory? category,
    ItemPriority? priority,
    int? quantity,
    bool? isClaimed,
    String? claimedByUserId,
    String? claimedByDisplayName,
    String? claimedByAvatarUrl,
    String? commitStatus,
    String? commitNote,
    String? commitUid,
    DateTime? claimedAt,
    DateTime? claimExpiresAt,
    DateTime? purchasedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ListItem(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      retailerUrl: retailerUrl ?? this.retailerUrl,
      amazonAsin: amazonAsin ?? this.amazonAsin,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      quantity: quantity ?? this.quantity,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      claimedByDisplayName: claimedByDisplayName ?? this.claimedByDisplayName,
      claimedByAvatarUrl: claimedByAvatarUrl ?? this.claimedByAvatarUrl,
      commitStatus: commitStatus ?? this.commitStatus,
      commitNote: commitNote ?? this.commitNote,
      commitUid: commitUid ?? this.commitUid,
      claimedAt: claimedAt ?? this.claimedAt,
      claimExpiresAt: claimExpiresAt ?? this.claimExpiresAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted price string using the item's currency
  String get formattedPrice {
    if (price == null) return '';
    final currencyObj = Currency.fromCode(currency ?? 'GBP');
    return currencyObj.format(price!);
  }

  /// Check if item has an Amazon affiliate link
  bool get hasAmazonLink => amazonAsin != null && amazonAsin!.isNotEmpty;

  /// Check if item has any image
  bool get hasImage => thumbnailUrl != null || mainImageUrl != null;

  /// Get the best available image URL
  String? get imageUrl => mainImageUrl ?? thumbnailUrl;

  /// Check if claim is expired
  bool get isClaimExpired {
    if (claimExpiresAt == null) return false;
    return DateTime.now().isAfter(claimExpiresAt!);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListItem && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'ListItem(uid: $uid, name: $name)';
}
