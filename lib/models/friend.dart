/// Friend model representing a connection between two users
/// Friendships are bidirectional - this model handles both directions
class Friend {
  final int id;
  final String ownerId;
  final String friendUserId;
  final String? nickname;
  final DateTime createdAt;
  
  // Joined data from the friend's user profile
  final String? friendDisplayName;
  final String? friendEmail;
  final String? friendAvatarUrl;

  Friend({
    required this.id,
    required this.ownerId,
    required this.friendUserId,
    this.nickname,
    required this.createdAt,
    this.friendDisplayName,
    this.friendEmail,
    this.friendAvatarUrl,
  });

  /// Display name to show (nickname if set, otherwise friend's display name)
  String get displayName => nickname ?? friendDisplayName ?? 'Unknown';

  /// Get initials for avatar
  String get initials {
    final name = displayName;
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Parse from JSON where current user is user_id (I added them)
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as int,
      ownerId: json['user_id'] as String,
      friendUserId: json['friend_user_id'] as String,
      nickname: json['nickname'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      // Joined user data - 'friend' is the alias for friend_user_id join
      friendDisplayName: json['friend']?['display_name'] as String?,
      friendEmail: json['friend']?['email'] as String?,
      friendAvatarUrl: json['friend']?['avatar_url'] as String?,
    );
  }

  /// Parse from JSON where current user is friend_user_id (they added me)
  /// In this case, the 'friend' join points to user_id (the person who added me)
  factory Friend.fromJsonReverse(Map<String, dynamic> json, String theirUserId) {
    return Friend(
      id: json['id'] as int,
      ownerId: json['friend_user_id'] as String, // I am friend_user_id
      friendUserId: theirUserId, // They are user_id
      nickname: json['nickname'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      // Joined user data - 'friend' is the alias for user_id join in reverse query
      friendDisplayName: json['friend']?['display_name'] as String?,
      friendEmail: json['friend']?['email'] as String?,
      friendAvatarUrl: json['friend']?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': ownerId,
      'friend_user_id': friendUserId,
      'nickname': nickname,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
