/// Model for in-app notifications
class AppNotificationModel {
  final int id;
  final String uid;
  final String userId;
  final String type;
  final String title;
  final String? message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.uid,
    required this.userId,
    required this.type,
    required this.title,
    this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as int,
      uid: json['uid'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotificationModel copyWith({
    int? id,
    String? uid,
    String? userId,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get icon based on notification type
  String get iconType {
    switch (type) {
      case 'commit':
        return 'handshake';
      case 'purchase':
        return 'shopping_cart';
      case 'friend_request':
        return 'user_plus';
      case 'friend_accepted':
        return 'users';
      case 'list_shared':
        return 'share';
      default:
        return 'bell';
    }
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

