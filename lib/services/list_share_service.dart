import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wish_list.dart';

/// Service for managing list shares (sharing lists with friends)
class ListShareService {
  final _client = Supabase.instance.client;
  static const _tableName = 'list_shares';

  /// Get all list UIDs shared with a specific user
  Future<List<String>> getListsSharedWithUser(String userId) async {
    final response = await _client
        .from(_tableName)
        .select('list_uid')
        .eq('shared_with_user_id', userId);

    return (response as List).map((r) => r['list_uid'] as String).toList();
  }

  /// Get all users a list is shared with
  Future<List<String>> getUsersForList(String listUid) async {
    final response = await _client
        .from(_tableName)
        .select('shared_with_user_id')
        .eq('list_uid', listUid);

    return (response as List)
        .map((r) => r['shared_with_user_id'] as String)
        .toList();
  }

  /// Share a list with a user
  Future<void> shareListWithUser(
    String listUid,
    String userId, {
    bool canEdit = false,
  }) async {
    await _client.from(_tableName).upsert({
      'list_uid': listUid,
      'shared_with_user_id': userId,
      'can_edit': canEdit,
    }, onConflict: 'list_uid,shared_with_user_id');
  }

  /// Share multiple lists with a user
  Future<void> shareListsWithUser(
    List<String> listUids,
    String userId, {
    bool canEdit = false,
  }) async {
    final inserts =
        listUids
            .map(
              (listUid) => {
                'list_uid': listUid,
                'shared_with_user_id': userId,
                'can_edit': canEdit,
              },
            )
            .toList();

    await _client
        .from(_tableName)
        .upsert(inserts, onConflict: 'list_uid,shared_with_user_id');
  }

  /// Share a list with multiple users
  Future<void> shareListWithUsers(
    String listUid,
    List<String> userIds, {
    bool canEdit = false,
  }) async {
    final inserts =
        userIds
            .map(
              (userId) => {
                'list_uid': listUid,
                'shared_with_user_id': userId,
                'can_edit': canEdit,
              },
            )
            .toList();

    await _client
        .from(_tableName)
        .upsert(inserts, onConflict: 'list_uid,shared_with_user_id');
  }

  /// Remove a user's access to a list
  Future<void> unshareListWithUser(String listUid, String userId) async {
    await _client
        .from(_tableName)
        .delete()
        .eq('list_uid', listUid)
        .eq('shared_with_user_id', userId);
  }

  /// Remove multiple lists from a user
  Future<void> unshareListsWithUser(
    List<String> listUids,
    String userId,
  ) async {
    for (final listUid in listUids) {
      await _client
          .from(_tableName)
          .delete()
          .eq('list_uid', listUid)
          .eq('shared_with_user_id', userId);
    }
  }

  /// Remove a list from multiple users
  Future<void> unshareListWithUsers(
    String listUid,
    List<String> userIds,
  ) async {
    for (final userId in userIds) {
      await _client
          .from(_tableName)
          .delete()
          .eq('list_uid', listUid)
          .eq('shared_with_user_id', userId);
    }
  }

  /// Check if a list is shared with a user
  Future<bool> isListSharedWithUser(String listUid, String userId) async {
    final response =
        await _client
            .from(_tableName)
            .select('id')
            .eq('list_uid', listUid)
            .eq('shared_with_user_id', userId)
            .maybeSingle();

    return response != null;
  }

  /// Get lists owned by current user with share counts
  Future<List<WishList>> getMyListsWithShareInfo() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('lists')
        .select('*')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => WishList.fromJson(json)).toList();
  }
}
