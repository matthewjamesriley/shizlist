import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/models.dart';
import '../core/constants/supabase_config.dart';

/// Service for managing wish lists
class ListService {
  final SupabaseClient _client = SupabaseService.client;
  final _uuid = const Uuid();

  /// Get all lists for the current user (excluding deleted)
  Future<List<WishList>> getUserLists() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(SupabaseConfig.listsTable)
        .select()
        .eq('owner_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => WishList.fromJson(json))
        .toList();
  }

  /// Get a single list by UID
  Future<WishList?> getListByUid(String uid) async {
    final response = await _client
        .from(SupabaseConfig.listsTable)
        .select()
        .eq('uid', uid)
        .maybeSingle();

    if (response == null) return null;
    return WishList.fromJson(response);
  }

  /// Create a new list
  Future<WishList> createList({
    required String title,
    String? description,
    ListVisibility visibility = ListVisibility.private,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final uid = _uuid.v4();
    final response = await _client
        .from(SupabaseConfig.listsTable)
        .insert({
          'uid': uid,
          'owner_id': userId,
          'title': title,
          'description': description,
          'visibility': visibility == ListVisibility.public ? 'public' : 'private',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return WishList.fromJson(response);
  }

  /// Update an existing list
  Future<WishList> updateList({
    required String uid,
    String? title,
    String? description,
    String? coverImageUrl,
    ListVisibility? visibility,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
    if (visibility != null) {
      updates['visibility'] = visibility == ListVisibility.public ? 'public' : 'private';
    }

    final response = await _client
        .from(SupabaseConfig.listsTable)
        .update(updates)
        .eq('uid', uid)
        .select()
        .single();

    return WishList.fromJson(response);
  }

  /// Soft delete a list (marks as deleted, doesn't remove data)
  Future<void> deleteList(String uid) async {
    await _client
        .from(SupabaseConfig.listsTable)
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('uid', uid);
  }

  /// Permanently delete a list (hard delete)
  Future<void> permanentlyDeleteList(String uid) async {
    await _client
        .from(SupabaseConfig.listsTable)
        .delete()
        .eq('uid', uid);
  }

  /// Restore a soft-deleted list
  Future<void> restoreList(String uid) async {
    await _client
        .from(SupabaseConfig.listsTable)
        .update({
          'is_deleted': false,
          'deleted_at': null,
        })
        .eq('uid', uid);
  }

  /// Get lists shared with current user
  Future<List<WishList>> getSharedLists() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from(SupabaseConfig.listSharesTable)
        .select('list_id, ${SupabaseConfig.listsTable}(*)')
        .eq('shared_with_user_id', userId);

    return (response as List)
        .map((json) => WishList.fromJson(json[SupabaseConfig.listsTable]))
        .toList();
  }

  /// Share a list with a user
  Future<void> shareList({
    required int listId,
    required String userId,
    bool canEdit = false,
  }) async {
    await _client.from(SupabaseConfig.listSharesTable).insert({
      'list_id': listId,
      'shared_with_user_id': userId,
      'can_edit': canEdit,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Remove list share
  Future<void> unshareList({
    required int listId,
    required String userId,
  }) async {
    await _client
        .from(SupabaseConfig.listSharesTable)
        .delete()
        .eq('list_id', listId)
        .eq('shared_with_user_id', userId);
  }

  /// Subscribe to real-time list changes
  RealtimeChannel subscribeToListChanges(
    String listUid,
    void Function(WishList) onUpdate,
  ) {
    return _client
        .channel('list_$listUid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.listsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'uid',
            value: listUid,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(WishList.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }
}


