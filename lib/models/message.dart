import 'package:flutter/foundation.dart';

/// Message scope enum defining who can see the message
enum MessageScope {
  allGifters,      // All gifters (not creator)
  everyone,         // Everyone including creator
  creatorOnly,      // Direct message to creator only
  selectedGifters;  // Specific selected users

  String get displayName {
    switch (this) {
      case MessageScope.allGifters:
        return 'All Gifters';
      case MessageScope.everyone:
        return 'Everyone';
      case MessageScope.creatorOnly:
        return 'Creator Only';
      case MessageScope.selectedGifters:
        return 'Selected Gifters';
    }
  }

  static MessageScope fromString(String value) {
    switch (value.toLowerCase()) {
      case 'all_gifters':
        return MessageScope.allGifters;
      case 'everyone':
        return MessageScope.everyone;
      case 'creator_only':
        return MessageScope.creatorOnly;
      case 'selected_gifters':
        return MessageScope.selectedGifters;
      default:
        return MessageScope.everyone;
    }
  }

  String toDbString() {
    switch (this) {
      case MessageScope.allGifters:
        return 'all_gifters';
      case MessageScope.everyone:
        return 'everyone';
      case MessageScope.creatorOnly:
        return 'creator_only';
      case MessageScope.selectedGifters:
        return 'selected_gifters';
    }
  }
}

/// Message model for group conversations
@immutable
class Message {
  final int id;
  final String uid;
  final int conversationId;
  final String senderUserId;
  final String content;
  final MessageScope scope;
  final List<String>? visibleToUserIds;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  // Joined data
  final String? senderDisplayName;
  final String? senderAvatarUrl;

  const Message({
    required this.id,
    required this.uid,
    required this.conversationId,
    required this.senderUserId,
    required this.content,
    required this.scope,
    this.visibleToUserIds,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.senderDisplayName,
    this.senderAvatarUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      uid: json['uid'] as String,
      conversationId: json['conversation_id'] as int,
      senderUserId: json['sender_user_id'] as String,
      content: json['content'] as String,
      scope: MessageScope.fromString(json['scope'] as String? ?? 'everyone'),
      visibleToUserIds: json['visible_to_user_ids'] != null
          ? List<String>.from(json['visible_to_user_ids'] as List)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      senderDisplayName: json['sender_display_name'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'conversation_id': conversationId,
      'sender_user_id': senderUserId,
      'content': content,
      'scope': scope.toDbString(),
      'visible_to_user_ids': visibleToUserIds,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// Create a new message for insertion
  Map<String, dynamic> toInsertJson() {
    return {
      'uid': uid,
      'conversation_id': conversationId,
      'sender_user_id': senderUserId,
      'content': content,
      'scope': scope.toDbString(),
      'visible_to_user_ids': visibleToUserIds,
    };
  }

  Message copyWith({
    int? id,
    String? uid,
    int? conversationId,
    String? senderUserId,
    String? content,
    MessageScope? scope,
    List<String>? visibleToUserIds,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isDeleted,
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) {
    return Message(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      conversationId: conversationId ?? this.conversationId,
      senderUserId: senderUserId ?? this.senderUserId,
      content: content ?? this.content,
      scope: scope ?? this.scope,
      visibleToUserIds: visibleToUserIds ?? this.visibleToUserIds,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
    );
  }

  /// Check if message has been edited
  bool get wasEdited => editedAt != null;

  /// Get sender initials for avatar
  String get senderInitials {
    if (senderDisplayName != null && senderDisplayName!.isNotEmpty) {
      final parts = senderDisplayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return senderDisplayName![0].toUpperCase();
    }
    return '?';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'Message(uid: $uid, content: ${content.substring(0, content.length.clamp(0, 20))})';
}


