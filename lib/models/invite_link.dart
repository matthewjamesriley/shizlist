/// Model representing an invite link
class InviteLink {
  final int id;
  final String uid;
  final String ownerId;
  final int? listId;
  final String code;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final int usesCount;
  
  // Joined data
  final String? listTitle;
  final String? ownerName;
  final String? ownerAvatarUrl;

  InviteLink({
    required this.id,
    required this.uid,
    required this.ownerId,
    this.listId,
    required this.code,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.usesCount = 0,
    this.listTitle,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) {
    return InviteLink(
      id: json['id'] as int,
      uid: json['uid'] as String,
      ownerId: json['owner_id'] as String,
      listId: json['list_id'] as int?,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
      isActive: json['is_active'] as bool? ?? true,
      usesCount: json['uses_count'] as int? ?? 0,
      listTitle: json['lists']?['title'] as String?,
      ownerName: json['users']?['display_name'] as String?,
      ownerAvatarUrl: json['users']?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'owner_id': ownerId,
      'list_id': listId,
      'code': code,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'uses_count': usesCount,
    };
  }

  /// Get the full invite URL
  String get inviteUrl => 'https://shizlist.co/invite/$code';

  /// Check if invite has a linked list
  bool get hasLinkedList => listId != null;

  /// Check if invite is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if invite is valid (active and not expired)
  bool get isValid => isActive && !isExpired;
}

