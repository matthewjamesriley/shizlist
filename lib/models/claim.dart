import 'package:flutter/foundation.dart';

/// Claim status enum
enum ClaimStatus {
  active,
  expired,
  purchased,
  cancelled;

  String get displayName {
    switch (this) {
      case ClaimStatus.active:
        return 'Committed';
      case ClaimStatus.expired:
        return 'Expired';
      case ClaimStatus.purchased:
        return 'Purchased';
      case ClaimStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ClaimStatus fromString(String value) {
    return ClaimStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ClaimStatus.active,
    );
  }
}

/// Claim model representing a user's claim on a list item
@immutable
class Claim {
  final int id;
  final String uid;
  final int itemId;
  final String claimedByUserId;
  final ClaimStatus status;
  final String? note;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? purchasedAt;

  const Claim({
    required this.id,
    required this.uid,
    required this.itemId,
    required this.claimedByUserId,
    required this.status,
    this.note,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
    this.purchasedAt,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as int,
      uid: json['uid'] as String,
      itemId: json['item_id'] as int,
      claimedByUserId: json['claimed_by_user_id'] as String,
      status: ClaimStatus.fromString(json['status'] as String? ?? 'active'),
      note: json['note'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'item_id': itemId,
      'claimed_by_user_id': claimedByUserId,
      'status': status.name,
      'note': note,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'purchased_at': purchasedAt?.toIso8601String(),
    };
  }

  /// Create a new claim for insertion
  Map<String, dynamic> toInsertJson() {
    return {
      'uid': uid,
      'item_id': itemId,
      'claimed_by_user_id': claimedByUserId,
      'status': status.name,
      'note': note,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  Claim copyWith({
    int? id,
    String? uid,
    int? itemId,
    String? claimedByUserId,
    ClaimStatus? status,
    String? note,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? purchasedAt,
  }) {
    return Claim(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      itemId: itemId ?? this.itemId,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      status: status ?? this.status,
      note: note ?? this.note,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
    );
  }

  /// Check if claim is active
  bool get isActive => status == ClaimStatus.active && !isExpired;

  /// Check if claim is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if claim has been purchased
  bool get isPurchased => status == ClaimStatus.purchased;

  /// Get days until expiration
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Claim && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'Claim(uid: $uid, itemId: $itemId, status: $status)';
}


