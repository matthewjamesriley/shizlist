import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/models.dart';
import '../core/constants/supabase_config.dart';

/// Search result with item and list info
class ItemSearchResult {
  final ListItem item;
  final String listUid;
  final String listTitle;

  const ItemSearchResult({
    required this.item,
    required this.listUid,
    required this.listTitle,
  });
}

/// Service for managing list items
class ItemService {
  final SupabaseClient _client = SupabaseService.client;
  final _uuid = const Uuid();

  /// Search all items across all lists for the current user
  Future<List<ItemSearchResult>> searchAllItems(String query) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    if (query.trim().isEmpty) return [];

    // Get all items from user's lists that match the search query
    final response = await _client
        .from(SupabaseConfig.listItemsTable)
        .select('*, lists!inner(uid, title, owner_id, is_deleted)')
        .eq('lists.owner_id', userId)
        .eq('lists.is_deleted', false)
        .ilike('name', '%${query.trim()}%')
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List).map((json) {
      final listData = json['lists'] as Map<String, dynamic>;
      final itemJson = Map<String, dynamic>.from(json);
      itemJson.remove('lists');

      return ItemSearchResult(
        item: ListItem.fromJson(itemJson),
        listUid: listData['uid'] as String,
        listTitle: listData['title'] as String,
      );
    }).toList();
  }

  /// Get all items for a list with commit data
  Future<List<ListItem>> getListItems(int listId) async {
    // First, get the items
    final itemsResponse = await _client
        .from(SupabaseConfig.listItemsTable)
        .select()
        .eq('list_id', listId)
        .order('created_at', ascending: false);

    final items = itemsResponse as List;
    if (items.isEmpty) return [];

    // Get all item UIDs
    final itemUids = items.map((i) => i['uid'] as String).toList();

    // Fetch commits separately for these items
    final commitsResponse = await _client
        .from(SupabaseConfig.commitsTable)
        .select()
        .inFilter('item_uid', itemUids)
        .inFilter('status', ['active', 'purchased']);

    // Create a map of item_uid -> commit
    final commitsMap = <String, Map<String, dynamic>>{};
    final committerUserIds = <String>{};
    for (final commit in (commitsResponse as List)) {
      final itemUid = commit['item_uid'] as String;
      // Only keep first active/purchased commit per item
      if (!commitsMap.containsKey(itemUid)) {
        commitsMap[itemUid] = commit as Map<String, dynamic>;
        final userId = commit['claimed_by_user_id'] as String?;
        if (userId != null) {
          committerUserIds.add(userId);
        }
      }
    }

    // Fetch user data for all committers
    final usersMap = <String, Map<String, dynamic>>{};
    if (committerUserIds.isNotEmpty) {
      final usersResponse = await _client
          .from(SupabaseConfig.usersTable)
          .select('uid, display_name, avatar_url')
          .inFilter('uid', committerUserIds.toList());
      for (final user in (usersResponse as List)) {
        usersMap[user['uid'] as String] = user as Map<String, dynamic>;
      }
    }

    // Map items with their commits
    return items.map((json) {
      final itemJson = Map<String, dynamic>.from(json);
      final itemUid = itemJson['uid'] as String;

      final commit = commitsMap[itemUid];
      if (commit != null) {
        itemJson['is_claimed'] = true;
        itemJson['claimed_by_user_id'] = commit['claimed_by_user_id'];
        itemJson['commit_uid'] = commit['uid'];
        itemJson['commit_status'] = commit['status'];
        itemJson['commit_note'] = commit['note'];
        itemJson['claimed_at'] = commit['created_at'];
        itemJson['claim_expires_at'] = commit['expires_at'];
        itemJson['purchased_at'] = commit['purchased_at'];

        // Get display name and avatar from users map
        final userId = commit['claimed_by_user_id'] as String?;
        if (userId != null) {
          final userData = usersMap[userId];
        if (userData != null) {
          itemJson['claimed_by_display_name'] = userData['display_name'];
          itemJson['claimed_by_avatar_url'] = userData['avatar_url'];
          }
        }
      }

      return ListItem.fromJson(itemJson);
    }).toList();
  }

  /// Get a single item by UID
  Future<ListItem?> getItemByUid(String uid) async {
    final response =
        await _client
            .from(SupabaseConfig.listItemsTable)
            .select()
            .eq('uid', uid)
            .maybeSingle();

    if (response == null) return null;
    return ListItem.fromJson(response);
  }

  /// Create a new item (Quick Add)
  Future<ListItem> createItem({
    required int listId,
    required String name,
    String? description,
    double? price,
    String? currency,
    String? retailerUrl,
    String? thumbnailUrl,
    String? mainImageUrl,
    required ItemCategory category,
    ItemPriority priority = ItemPriority.none,
    int quantity = 1,
  }) async {
    final uid = _uuid.v4();
    final response =
        await _client
            .from(SupabaseConfig.listItemsTable)
            .insert({
              'uid': uid,
              'list_id': listId,
              'name': name,
              'description': description,
              'price': price,
              'currency': currency ?? 'USD',
              'retailer_url': retailerUrl,
              'thumbnail_url': thumbnailUrl,
              'main_image_url': mainImageUrl,
              'category': category.name,
              'priority': priority.name,
              'quantity': quantity,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

    return ListItem.fromJson(response);
  }

  /// Create item from Amazon product
  Future<ListItem> createItemFromAmazon({
    required int listId,
    required String name,
    String? description,
    double? price,
    String? thumbnailUrl,
    String? mainImageUrl,
    required String amazonAsin,
    required String affiliateUrl,
    required ItemCategory category,
  }) async {
    final uid = _uuid.v4();
    final response =
        await _client
            .from(SupabaseConfig.listItemsTable)
            .insert({
              'uid': uid,
              'list_id': listId,
              'name': name,
              'description': description,
              'price': price,
              'currency': 'USD',
              'thumbnail_url': thumbnailUrl,
              'main_image_url': mainImageUrl,
              'retailer_url': affiliateUrl,
              'amazon_asin': amazonAsin,
              'category': category.name,
              'priority': ItemPriority.none.name,
              'quantity': 1,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

    return ListItem.fromJson(response);
  }

  /// Update an existing item
  /// Pass empty string to clear optional text fields (description, retailerUrl, etc.)
  Future<ListItem> updateItem({
    required String uid,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? thumbnailUrl,
    String? mainImageUrl,
    String? retailerUrl,
    ItemCategory? category,
    ItemPriority? priority,
    int? quantity,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    // For description: null = don't update, empty string = clear, other = set value
    if (description != null) {
      updates['description'] = description.isEmpty ? null : description;
    }
    if (price != null) updates['price'] = price;
    if (currency != null) updates['currency'] = currency;
    if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
    if (mainImageUrl != null) updates['main_image_url'] = mainImageUrl;
    // For retailerUrl: null = don't update, empty string = clear, other = set value
    if (retailerUrl != null) {
      updates['retailer_url'] = retailerUrl.isEmpty ? null : retailerUrl;
    }
    if (category != null) updates['category'] = category.name;
    if (priority != null) updates['priority'] = priority.name;
    if (quantity != null) updates['quantity'] = quantity;

    final response =
        await _client
            .from(SupabaseConfig.listItemsTable)
            .update(updates)
            .eq('uid', uid)
            .select()
            .single();

    return ListItem.fromJson(response);
  }

  /// Delete an item
  Future<void> deleteItem(String uid) async {
    await _client.from(SupabaseConfig.listItemsTable).delete().eq('uid', uid);
  }

  /// Commit to an item (for gifters)
  Future<void> commitToItem({
    required String itemUid,
    DateTime? expiresAt,
    String? note,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Direct insert into commits table
    await _client.from(SupabaseConfig.commitsTable).insert({
      'claimed_by_user_id': userId,
      'item_uid': itemUid,
      'status': 'active',
      if (note != null && note.isNotEmpty) 'note': note,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    });
  }

  /// Remove commitment to an item
  Future<void> uncommitFromItem(String itemUid) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Delete active commit for this user and item
    await _client
        .from(SupabaseConfig.commitsTable)
        .delete()
        .eq('item_uid', itemUid)
        .eq('claimed_by_user_id', userId)
        .eq('status', 'active');
  }

  /// Mark commit as purchased
  Future<void> markAsPurchased(String commitUid) async {
    await _client
        .from(SupabaseConfig.commitsTable)
        .update({
          'status': 'purchased',
          'purchased_at': DateTime.now().toIso8601String(),
        })
        .eq('uid', commitUid);
  }

  /// Get items with claim status for gifters (excluding owner view)
  Future<List<ListItem>> getItemsForGifter(int listId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // This should use a view or function that shows claim status
    // but hides it from the list owner
    final response = await _client
        .from(SupabaseConfig.publicListItemsView)
        .select()
        .eq('list_id', listId);

    return (response as List).map((json) => ListItem.fromJson(json)).toList();
  }

  /// Subscribe to real-time item changes
  RealtimeChannel subscribeToItemChanges(
    int listId,
    void Function(List<ListItem>) onUpdate,
  ) {
    return _client
        .channel('items_$listId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.listItemsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: listId,
          ),
          callback: (payload) async {
            // Refetch all items on any change
            final items = await getListItems(listId);
            onUpdate(items);
          },
        )
        .subscribe();
  }
}
