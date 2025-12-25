import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend.dart';

/// Service for managing friends/contacts
/// Friendships are bidirectional - if A adds B, both see each other as friends
class FriendService {
  final _client = Supabase.instance.client;
  static const _tableName = 'friends';

  /// Get all friends for the current user (both directions)
  Future<List<Friend>> getFriends() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Single query to get all friendship rows where I'm involved
    final response = await _client
        .from(_tableName)
        .select('*')
        .or('user_id.eq.$userId,friend_user_id.eq.$userId')
        .order('created_at', ascending: false);

    final List<Friend> allFriends = [];
    final Set<String> seenFriendIds = {};

    for (final json in response as List) {
      try {
        final oderId = json['user_id'] as String;
        final friendUserId = json['friend_user_id'] as String;
        
        // Determine which ID is the "other person"
        final otherUserId = (oderId == userId) ? friendUserId : oderId;
        
        // Skip if we've already seen this friend
        if (seenFriendIds.contains(otherUserId)) continue;
        seenFriendIds.add(otherUserId);

        // Fetch the other user's profile
        final userProfile = await _client
            .from('users')
            .select('display_name, email, avatar_url')
            .eq('uid', otherUserId)
            .maybeSingle();

        final friend = Friend(
          id: json['id'] as int,
          ownerId: oderId,
          friendUserId: otherUserId,
          nickname: json['nickname'] as String?,
          createdAt: DateTime.parse(json['created_at'] as String),
          friendDisplayName: userProfile?['display_name'] as String?,
          friendEmail: userProfile?['email'] as String?,
          friendAvatarUrl: userProfile?['avatar_url'] as String?,
        );
        
        allFriends.add(friend);
      } catch (e) {
        print('Error parsing friend: $e');
      }
    }

    return allFriends;
  }

  /// Search friends by name or email
  Future<List<Friend>> searchFriends(String query) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final friends = await getFriends();
    
    final lowerQuery = query.toLowerCase();
    return friends.where((friend) {
      final name = friend.displayName.toLowerCase();
      final email = friend.friendEmail?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  /// Add a friend by their user ID
  Future<Friend> addFriend(String friendUserId, {String? nickname}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Check if friendship already exists in either direction
    final existing = await _client
        .from(_tableName)
        .select('id')
        .or('and(user_id.eq.$userId,friend_user_id.eq.$friendUserId),and(user_id.eq.$friendUserId,friend_user_id.eq.$userId)')
        .maybeSingle();

    if (existing != null) {
      throw Exception('Already friends');
    }

    final response = await _client
        .from(_tableName)
        .insert({
          'user_id': userId,
          'friend_user_id': friendUserId,
          'nickname': nickname,
        })
        .select('*, friend:friend_user_id(display_name, email, avatar_url)')
        .single();

    return Friend.fromJson(response);
  }

  /// Add a friend by their email (looks up the user first)
  Future<Friend?> addFriendByEmail(String email, {String? nickname}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Find the user by email
    final userResponse = await _client
        .from('users')
        .select('uid')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (userResponse == null) {
      return null; // User not found
    }

    final friendUserId = userResponse['uid'] as String;
    
    // Can't add yourself
    if (friendUserId == userId) {
      throw Exception('Cannot add yourself as a friend');
    }

    return addFriend(friendUserId, nickname: nickname);
  }

  /// Update a friend's nickname
  Future<void> updateNickname(int friendId, String? nickname) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Try updating where I am user_id
    final result = await _client
        .from(_tableName)
        .update({'nickname': nickname})
        .eq('id', friendId)
        .eq('user_id', userId)
        .select();

    // If no rows updated, try where I am friend_user_id
    if ((result as List).isEmpty) {
      await _client
          .from(_tableName)
          .update({'nickname': nickname})
          .eq('id', friendId)
          .eq('friend_user_id', userId);
    }
  }

  /// Remove a friend (removes the friendship for both users)
  Future<void> removeFriend(int friendId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // First, get the friendship record to find both user IDs
    final record = await _client
        .from(_tableName)
        .select('user_id, friend_user_id')
        .eq('id', friendId)
        .maybeSingle();

    if (record == null) {
      throw Exception('Friendship not found');
    }

    final recordUserId = record['user_id'] as String;
    final recordFriendId = record['friend_user_id'] as String;

    // Verify current user is part of this friendship
    if (recordUserId != userId && recordFriendId != userId) {
      throw Exception('Not authorized to delete this friendship');
    }

    // Determine the friend's user ID
    final friendUserId = (recordUserId == userId) ? recordFriendId : recordUserId;

    // Delete all list shares between these users (both directions)
    // 1. Lists current user shared with the friend
    final myLists = await _client
        .from('lists')
        .select('uid')
        .eq('owner_id', userId);
    
    for (final list in (myLists as List)) {
      await _client
          .from('list_shares')
          .delete()
          .eq('list_uid', list['uid'])
          .eq('shared_with_user_id', friendUserId);
    }

    // 2. Lists the friend shared with current user
    final friendLists = await _client
        .from('lists')
        .select('uid')
        .eq('owner_id', friendUserId);
    
    for (final list in (friendLists as List)) {
      await _client
          .from('list_shares')
          .delete()
          .eq('list_uid', list['uid'])
          .eq('shared_with_user_id', userId);
    }

    // Delete the friendship record
    await _client
        .from(_tableName)
        .delete()
        .eq('id', friendId);
  }

  /// Check if a user is already a friend (either direction)
  Future<bool> isFriend(String friendUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from(_tableName)
        .select('id')
        .or('and(user_id.eq.$userId,friend_user_id.eq.$friendUserId),and(user_id.eq.$friendUserId,friend_user_id.eq.$userId)')
        .maybeSingle();

    return response != null;
  }
}
