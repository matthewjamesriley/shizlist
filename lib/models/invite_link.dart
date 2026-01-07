/// Model representing an invite link
class InviteLink {
  final int id;
  final String uid;
  final String ownerId;
  final List<String> listUids; // Array of list UIDs to share
  final String code;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final int usesCount;
  
  // Joined data
  final List<String> listTitles; // Titles of lists being shared
  final String? ownerName;
  final String? ownerAvatarUrl;

  // Legacy fields (for backward compatibility)
  final String? listUid; // Single list UID (deprecated)
  final bool shareAllLists; // Legacy flag (deprecated)

  InviteLink({
    required this.id,
    required this.uid,
    required this.ownerId,
    this.listUids = const [],
    required this.code,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.usesCount = 0,
    this.listTitles = const [],
    this.ownerName,
    this.ownerAvatarUrl,
    // Legacy
    this.listUid,
    this.shareAllLists = false,
  });

  factory InviteLink.fromJson(Map<String, dynamic> json) {
    // Parse list_uids array
    List<String> listUids = [];
    if (json['list_uids'] != null) {
      if (json['list_uids'] is List) {
        listUids = (json['list_uids'] as List).map((e) => e.toString()).toList();
      }
    }
    
    // Parse list titles (can be from joined data or separate query)
    List<String> listTitles = [];
    if (json['list_titles'] != null && json['list_titles'] is List) {
      listTitles = (json['list_titles'] as List).map((e) => e.toString()).toList();
    } else if (json['lists'] != null) {
      // Handle single list join (legacy)
      if (json['lists'] is Map && json['lists']['title'] != null) {
        listTitles = [json['lists']['title'] as String];
      } else if (json['lists'] is List) {
        listTitles = (json['lists'] as List)
            .where((l) => l['title'] != null)
            .map((l) => l['title'] as String)
            .toList();
      }
    }

    return InviteLink(
      id: json['id'] as int,
      uid: json['uid'] as String,
      ownerId: json['owner_id'] as String,
      listUids: listUids,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
      isActive: json['is_active'] as bool? ?? true,
      usesCount: json['uses_count'] as int? ?? 0,
      listTitles: listTitles,
      ownerName: json['users']?['display_name'] as String?,
      ownerAvatarUrl: json['users']?['avatar_url'] as String?,
      // Legacy fields
      listUid: json['list_uid'] as String?,
      shareAllLists: json['share_all_lists'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'owner_id': ownerId,
      'list_uids': listUids,
      'code': code,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'uses_count': usesCount,
    };
  }

  /// Get the full invite URL
  String get inviteUrl => 'https://shizlist.co/invite/$code';

  /// Check if invite has any linked lists
  bool get hasLinkedLists => listUids.isNotEmpty || listUid != null || shareAllLists;

  /// Get effective list UIDs (handles legacy single listUid)
  List<String> get effectiveListUids {
    if (listUids.isNotEmpty) return listUids;
    if (listUid != null) return [listUid!];
    return [];
  }

  /// Check if invite is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if invite is valid (active and not expired)
  bool get isValid => isActive && !isExpired;
  
  /// Get display text for the lists being shared
  String get listSummary {
    if (listTitles.isNotEmpty) {
      if (listTitles.length == 1) {
        return listTitles.first;
      }
      return '${listTitles.length} lists';
    }
    if (shareAllLists) return 'All lists';
    if (effectiveListUids.isEmpty) return 'No lists';
    return '${effectiveListUids.length} list${effectiveListUids.length > 1 ? 's' : ''}';
  }
}
