import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/models.dart';
import '../core/constants/supabase_config.dart';

String _visibilityToString(ListVisibility visibility) {
  switch (visibility) {
    case ListVisibility.public:
      return 'public';
    case ListVisibility.friends:
      return 'friends';
    case ListVisibility.private:
      return 'private';
  }
}

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
        .select('*, list_items(count)')
        .eq('owner_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    final lists = <WishList>[];
    for (final json in (response as List)) {
      // Extract item count from the nested list_items count
      final itemCount = json['list_items']?[0]?['count'] as int? ?? 0;
      final listJson = Map<String, dynamic>.from(json);
      listJson['item_count'] = itemCount;
      
      // Fetch claimed count for this list (active commits on items in this list)
      final listId = json['id'] as int;
      final itemUids = await _getItemUidsForList(listId);
      if (itemUids.isNotEmpty) {
        final claimedCountResponse = await _client
            .from('commits')
            .select('id')
            .eq('status', 'active')
            .inFilter('item_uid', itemUids);
        listJson['claimed_count'] = (claimedCountResponse as List).length;
      } else {
        listJson['claimed_count'] = 0;
      }
      
      lists.add(WishList.fromJson(listJson));
    }
    return lists;
  }
  
  /// Helper to get item UIDs for a list
  Future<List<String>> _getItemUidsForList(int listId) async {
    final response = await _client
        .from('list_items')
        .select('uid')
        .eq('list_id', listId);
    return (response as List).map((item) => item['uid'] as String).toList();
  }

  /// Get a single list by UID
  Future<WishList?> getListByUid(String uid) async {
    final response = await _client
        .from(SupabaseConfig.listsTable)
        .select('*, list_items(count)')
        .eq('uid', uid)
        .maybeSingle();

    if (response == null) return null;
    
    // Extract item count from the nested list_items count
    final itemCount = response['list_items']?[0]?['count'] as int? ?? 0;
    final listJson = Map<String, dynamic>.from(response);
    listJson['item_count'] = itemCount;
    
    // Fetch claimed count for this list (active commits on items in this list)
    final listId = response['id'] as int;
    final itemUids = await _getItemUidsForList(listId);
    if (itemUids.isNotEmpty) {
      final claimedCountResponse = await _client
          .from('commits')
          .select('id')
          .eq('status', 'active')
          .inFilter('item_uid', itemUids);
      listJson['claimed_count'] = (claimedCountResponse as List).length;
    } else {
      listJson['claimed_count'] = 0;
    }
    
    return WishList.fromJson(listJson);
  }

  /// Create a new list
  Future<WishList> createList({
    required String title,
    String? description,
    ListVisibility visibility = ListVisibility.private,
    DateTime? eventDate,
    bool isRecurring = false,
    bool notifyOnCommit = true,
    bool notifyOnPurchase = true,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final uid = _uuid.v4();
    final visibilityStr = _visibilityToString(visibility);
    debugPrint('Creating list with visibility: $visibility -> $visibilityStr');
    final insertData = <String, dynamic>{
      'uid': uid,
      'owner_id': userId,
      'title': title,
      'description': description,
      'visibility': visibilityStr,
      'created_at': DateTime.now().toIso8601String(),
      'notify_on_commit': notifyOnCommit,
      'notify_on_purchase': notifyOnPurchase,
    };
    
    if (eventDate != null) {
      insertData['event_date'] = eventDate.toIso8601String().split('T').first;
      insertData['is_recurring'] = isRecurring;
    }
    
    final response = await _client
        .from(SupabaseConfig.listsTable)
        .insert(insertData)
        .select()
        .single();

    return WishList.fromJson(response);
  }

  /// Update an existing list
  /// Set [clearDescription] to true to explicitly remove the description
  /// Set [clearEventDate] to true to remove the event date
  Future<WishList> updateList({
    required String uid,
    String? title,
    String? description,
    bool clearDescription = false,
    String? coverImageUrl,
    bool clearCoverImage = false,
    ListVisibility? visibility,
    DateTime? eventDate,
    bool clearEventDate = false,
    bool? isRecurring,
    bool? notifyOnCommit,
    bool? notifyOnPurchase,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (description != null) {
      updates['description'] = description;
    } else if (clearDescription) {
      updates['description'] = null;
    }
    if (coverImageUrl != null) {
      updates['cover_image_url'] = coverImageUrl;
    } else if (clearCoverImage) {
      updates['cover_image_url'] = null;
    }
    if (visibility != null) {
      updates['visibility'] = _visibilityToString(visibility);
    }
    if (eventDate != null) {
      updates['event_date'] = eventDate.toIso8601String().split('T').first;
    } else if (clearEventDate) {
      updates['event_date'] = null;
      updates['is_recurring'] = false;
    }
    if (isRecurring != null) {
      updates['is_recurring'] = isRecurring;
    }
    if (notifyOnCommit != null) {
      updates['notify_on_commit'] = notifyOnCommit;
    }
    if (notifyOnPurchase != null) {
      updates['notify_on_purchase'] = notifyOnPurchase;
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

    // Get all list UIDs shared with this user
    final sharesResponse = await _client
        .from(SupabaseConfig.listSharesTable)
        .select('list_uid')
        .eq('shared_with_user_id', userId);

    final listUids = (sharesResponse as List)
        .map((r) => r['list_uid'] as String)
        .toList();

    if (listUids.isEmpty) return [];

    // Fetch the actual lists by their UIDs
    final listsResponse = await _client
        .from(SupabaseConfig.listsTable)
        .select('*, list_items(count)')
        .inFilter('uid', listUids)
        .eq('is_deleted', false);

    final results = <WishList>[];
    for (final listData in (listsResponse as List)) {
      try {
        final itemCount = listData['list_items']?[0]?['count'] as int? ?? 0;
        final listJson = Map<String, dynamic>.from(listData);
        listJson['item_count'] = itemCount;
        
        // Fetch claimed count for this list
        final listId = listData['id'] as int;
        final itemUids = await _getItemUidsForList(listId);
        if (itemUids.isNotEmpty) {
          final claimedCountResponse = await _client
              .from('commits')
              .select('id')
              .eq('status', 'active')
              .inFilter('item_uid', itemUids);
          listJson['claimed_count'] = (claimedCountResponse as List).length;
        } else {
          listJson['claimed_count'] = 0;
        }
        
        results.add(WishList.fromJson(listJson));
      } catch (e) {
        debugPrint('Error parsing shared list: $e');
      }
    }
    return results;
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


