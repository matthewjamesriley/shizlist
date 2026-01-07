import 'dart:math';
import 'package:flutter/foundation.dart';
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

  /// Create a new invite link with selected lists
  /// [listUids] - List of list UIDs to share when invite is accepted
  Future<InviteLink> createInviteLink({required List<String> listUids}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final code = _generateCode();

    final data = {
      'owner_id': userId,
      'code': code,
      'list_uids': listUids,
      // Set legacy fields for backward compatibility
      'share_all_lists': false,
      'list_uid': listUids.isNotEmpty ? listUids.first : null,
    };

    final response =
        await _client.from(_tableName).insert(data).select().single();

    return InviteLink.fromJson(response);
  }

  /// Get all invite links for current user
  Future<List<InviteLink>> getUserInviteLinks() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(_tableName)
        .select('*')
        .eq('owner_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => InviteLink.fromJson(json)).toList();
  }

  /// Get invite link by code (public - for accepting invites)
  Future<InviteLink?> getInviteLinkByCode(String code) async {
    // Get the invite link first
    final response =
        await _client
            .from(_tableName)
            .select('*')
            .eq('code', code.toUpperCase())
            .eq('is_active', true)
            .maybeSingle();

    if (response == null) return null;

    // Fetch owner info separately (no FK relationship)
    final ownerId = response['owner_id'] as String?;
    if (ownerId != null) {
      final ownerResponse =
          await _client
              .from('users')
              .select('display_name, avatar_url')
              .eq('uid', ownerId)
              .maybeSingle();

      if (ownerResponse != null) {
        response['users'] = ownerResponse;
      }
    }

    // Fetch list titles for the list_uids
    final listUids = response['list_uids'] as List?;
    if (listUids != null && listUids.isNotEmpty) {
      final listsResponse = await _client
          .from('lists')
          .select('uid, title')
          .inFilter('uid', listUids.map((e) => e.toString()).toList());
      
      if (listsResponse.isNotEmpty) {
        response['list_titles'] = listsResponse.map((l) => l['title']).toList();
        response['lists'] = listsResponse;
      }
    }

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

  /// Accept an invite - adds friend and shares selected lists
  /// Returns a map with 'success', 'message', and optionally 'ownerName', 'listTitles'
  Future<Map<String, dynamic>> acceptInvite(String code) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return {
        'success': false,
        'message': 'Please sign in to accept this invite',
      };
    }

    // Get the invite
    final invite = await getInviteLinkByCode(code);
    if (invite == null) {
      return {
        'success': false,
        'message': 'This invite link is invalid or has expired',
      };
    }

    // Can't accept your own invite
    if (invite.ownerId == userId) {
      return {'success': false, 'message': 'You cannot accept your own invite'};
    }

    // Check if already friends
    final existingFriend =
        await _client
            .from('friends')
            .select('id')
            .or(
              'and(user_id.eq.$userId,friend_user_id.eq.${invite.ownerId}),and(user_id.eq.${invite.ownerId},friend_user_id.eq.$userId)',
            )
            .maybeSingle();

    if (existingFriend == null) {
      // Create friendship
      await _client.from('friends').insert({
        'user_id': userId,
        'friend_user_id': invite.ownerId,
      });
    }

    // Share lists - use effectiveListUids to handle both new and legacy invites
    final listUidsToShare = invite.effectiveListUids;
    int listsShared = 0;
    
    try {
      // Handle legacy shareAllLists flag
      if (invite.shareAllLists && listUidsToShare.isEmpty) {
        // Share all non-private lists from the invite owner
        final listsResponse = await _client
            .from('lists')
            .select('uid')
            .eq('owner_id', invite.ownerId)
            .neq('visibility', 'private')
            .eq('is_deleted', false);

        for (final listData in listsResponse as List) {
          final listUid = listData['uid'] as String;
          if (await _shareListWithUser(listUid, userId)) {
            listsShared++;
          }
        }
      } else {
        // Share specific lists from the invite
        for (final listUid in listUidsToShare) {
          if (await _shareListWithUser(listUid, userId)) {
            listsShared++;
          }
        }
      }
    } catch (e) {
      // List sharing failed due to RLS policy - friendship is still created
      debugPrint('List sharing failed (RLS): $e');
    }

    // Increment uses count
    try {
      await incrementUsesCount(code);
    } catch (e) {
      // Non-critical error, continue
    }

    // Build response message
    String message;
    if (existingFriend != null) {
      if (listsShared > 0) {
        message = 'Added to $listsShared new list${listsShared > 1 ? 's' : ''} from ${invite.ownerName ?? 'your friend'}!';
      } else {
        message = 'You\'re already connected with ${invite.ownerName ?? 'this user'}';
      }
    } else {
      if (listsShared > 0) {
        message = 'Connected with ${invite.ownerName ?? 'your new friend'} and added to $listsShared list${listsShared > 1 ? 's' : ''}!';
      } else {
        message = 'You\'re now connected with ${invite.ownerName ?? 'your new friend'}!';
      }
    }

    return {
      'success': true,
      'message': message,
      'ownerName': invite.ownerName,
      'listTitles': invite.listTitles,
      'listsShared': listsShared,
      'alreadyFriends': existingFriend != null,
    };
  }

  /// Helper to share a list with a user (checks for existing share)
  Future<bool> _shareListWithUser(String listUid, String userId) async {
    // Check if list is already shared
    final existingShare =
        await _client
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
      return true; // New share created
    }
    return false; // Already shared
  }
}
