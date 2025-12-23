import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/invite_link.dart';

/// Service for managing invite links
class InviteService {
  final SupabaseClient _client = SupabaseService.client;
  static const String _tableName = 'invite_links';
  static const String _baseUrl = 'https://shizlist.co/invite/';

  /// Generate a random invite code
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new invite link
  Future<InviteLink> createInviteLink({int? listId}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final code = _generateCode();
    
    final data = {
      'owner_id': userId,
      'code': code,
      if (listId != null) 'list_id': listId,
    };

    final response = await _client
        .from(_tableName)
        .insert(data)
        .select()
        .single();

    return InviteLink.fromJson(response);
  }

  /// Get all invite links for current user
  Future<List<InviteLink>> getUserInviteLinks() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(_tableName)
        .select('*, lists(title)')
        .eq('owner_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => InviteLink.fromJson(json)).toList();
  }

  /// Get invite link by code (public - for accepting invites)
  Future<InviteLink?> getInviteLinkByCode(String code) async {
    final response = await _client
        .from(_tableName)
        .select('*, lists(title), users!owner_id(display_name, avatar_url)')
        .eq('code', code.toUpperCase())
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return InviteLink.fromJson(response);
  }

  /// Increment uses count when invite is accepted
  Future<void> incrementUsesCount(String code) async {
    await _client.rpc('increment_invite_uses', params: {'invite_code': code});
  }

  /// Deactivate an invite link
  Future<void> deactivateInviteLink(String uid) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from(_tableName)
        .update({'is_active': false})
        .eq('uid', uid)
        .eq('owner_id', userId);
  }

  /// Delete an invite link
  Future<void> deleteInviteLink(String uid) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from(_tableName)
        .delete()
        .eq('uid', uid)
        .eq('owner_id', userId);
  }

  /// Get full invite URL
  static String getInviteUrl(String code) {
    return '$_baseUrl$code';
  }

  /// Accept an invite - adds friend and optionally shares list
  /// Returns a map with 'success', 'message', and optionally 'ownerName', 'listTitle'
  Future<Map<String, dynamic>> acceptInvite(String code) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': 'Please sign in to accept this invite'};
    }

    // Get the invite
    final invite = await getInviteLinkByCode(code);
    if (invite == null) {
      return {'success': false, 'message': 'This invite link is invalid or has expired'};
    }

    // Can't accept your own invite
    if (invite.ownerId == userId) {
      return {'success': false, 'message': 'You cannot accept your own invite'};
    }

    // Check if already friends
    final existingFriend = await _client
        .from('friends')
        .select('id')
        .or('and(user_id.eq.$userId,friend_user_id.eq.${invite.ownerId}),and(user_id.eq.${invite.ownerId},friend_user_id.eq.$userId)')
        .maybeSingle();

    if (existingFriend == null) {
      // Create friendship
      await _client.from('friends').insert({
        'user_id': userId,
        'friend_user_id': invite.ownerId,
      });
    }

    // If invite has a list, share it with the accepting user
    if (invite.listId != null) {
      final listId = invite.listId!;
      
      // Get the list UID first
      final listData = await _client
          .from('lists')
          .select('uid')
          .eq('id', listId)
          .maybeSingle();

      if (listData != null) {
        final listUid = listData['uid'] as String;
        
        // Check if list is already shared
        final existingShare = await _client
            .from('list_shares')
            .select('id')
            .eq('list_uid', listUid)
            .eq('shared_with_user_id', userId)
            .maybeSingle();

        if (existingShare == null) {
          await _client.from('list_shares').insert({
            'list_uid': listUid,
            'shared_with_user_id': userId,
            'can_edit': false,
          });
        }
      }
    }

    // Increment uses count
    try {
      await incrementUsesCount(code);
    } catch (e) {
      // Non-critical error, continue
    }

    return {
      'success': true,
      'message': existingFriend != null 
          ? 'You\'re already connected with ${invite.ownerName ?? 'this user'}'
          : 'You\'re now connected with ${invite.ownerName ?? 'your new friend'}!',
      'ownerName': invite.ownerName,
      'listTitle': invite.listTitle,
      'alreadyFriends': existingFriend != null,
    };
  }
}

