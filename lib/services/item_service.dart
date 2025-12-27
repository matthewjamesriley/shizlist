import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import '../models/models.dart';
import '../core/constants/supabase_config.dart';

/// Search result with item and list info
class ItemSearchResult {
  final ListItem item;
  final String listUid;
  final String listTitle;
  final bool isOwnItem;
  final String? ownerDisplayName;
  final String? ownerId;
  final bool notifyOnCommit;
  final bool notifyOnPurchase;

  const ItemSearchResult({
    required this.item,
    required this.listUid,
    required this.listTitle,
    this.isOwnItem = true,
    this.ownerDisplayName,
    this.ownerId,
    this.notifyOnCommit = true,
    this.notifyOnPurchase = true,
  });
}

/// Service for managing list items
class ItemService {
  final SupabaseClient _client = SupabaseService.client;
  final _uuid = const Uuid();

  /// Search all items across all lists for the current user (own + shared)
  Future<List<ItemSearchResult>> searchAllItems(String query) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    if (query.trim().isEmpty) return [];

    final searchTerm = '%${query.trim()}%';
    final results = <ItemSearchResult>[];

    try {

    // 1. Search user's own lists
    final ownResponse = await _client
        .from(SupabaseConfig.listItemsTable)
        .select('*, lists!inner(uid, title, owner_id, is_deleted, notify_on_commit, notify_on_purchase)')
        .eq('lists.owner_id', userId)
        .eq('lists.is_deleted', false)
        .ilike('name', searchTerm)
        .order('created_at', ascending: false)
        .limit(25);

    for (final json in (ownResponse as List)) {
      final listData = json['lists'] as Map<String, dynamic>;
      final itemJson = Map<String, dynamic>.from(json);
      itemJson.remove('lists');

      results.add(ItemSearchResult(
        item: ListItem.fromJson(itemJson),
        listUid: listData['uid'] as String,
        listTitle: listData['title'] as String,
        isOwnItem: true,
        ownerId: userId,
        notifyOnCommit: listData['notify_on_commit'] as bool? ?? true,
        notifyOnPurchase: listData['notify_on_purchase'] as bool? ?? true,
      ));
    }

    // 2. Get lists shared with user
    final sharesResponse = await _client
        .from(SupabaseConfig.listSharesTable)
        .select('list_uid')
        .eq('shared_with_user_id', userId);

    final sharedListUids = (sharesResponse as List)
        .map((r) => r['list_uid'] as String)
        .toList();

    if (sharedListUids.isNotEmpty) {
      // Get list IDs from UIDs
      final listsResponse = await _client
          .from(SupabaseConfig.listsTable)
          .select('id')
          .inFilter('uid', sharedListUids)
          .eq('is_deleted', false);
      
      final sharedListIds = (listsResponse as List)
          .map((r) => r['id'] as int)
          .toList();

      if (sharedListIds.isEmpty) return results;

      // Search items in shared lists by list_id
      final sharedResponse = await _client
          .from(SupabaseConfig.listItemsTable)
          .select('*, lists!inner(uid, title, owner_id, is_deleted, notify_on_commit, notify_on_purchase)')
          .inFilter('list_id', sharedListIds)
          .eq('lists.is_deleted', false)
          .ilike('name', searchTerm)
          .order('created_at', ascending: false)
          .limit(25);

      // Get owner profiles for shared lists
      final ownerIds = <String>{};
      for (final json in (sharedResponse as List)) {
        final listData = json['lists'] as Map<String, dynamic>;
        ownerIds.add(listData['owner_id'] as String);
      }

      Map<String, String> ownerNames = {};
      if (ownerIds.isNotEmpty) {
        final usersResponse = await _client
            .from(SupabaseConfig.usersTable)
            .select('uid, display_name, email')
            .inFilter('uid', ownerIds.toList());

        for (final user in (usersResponse as List)) {
          final id = user['uid'] as String;
          final displayName = user['display_name'] as String?;
          final email = user['email'] as String?;
          ownerNames[id] = displayName ?? email?.split('@').first ?? 'Friend';
        }
      }

      for (final json in (sharedResponse as List)) {
        final listData = json['lists'] as Map<String, dynamic>;
        final itemJson = Map<String, dynamic>.from(json);
        itemJson.remove('lists');
        final ownerId = listData['owner_id'] as String;

        results.add(ItemSearchResult(
          item: ListItem.fromJson(itemJson),
          listUid: listData['uid'] as String,
          listTitle: listData['title'] as String,
          isOwnItem: false,
          ownerId: ownerId,
          ownerDisplayName: ownerNames[ownerId] ?? 'Friend',
          notifyOnCommit: listData['notify_on_commit'] as bool? ?? true,
          notifyOnPurchase: listData['notify_on_purchase'] as bool? ?? true,
        ));
      }
    }

    // Sort by created_at descending
    results.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));

    return results.take(50).toList();
    } catch (e, stackTrace) {
      debugPrint('Search error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all items for a list with commit and purchase data
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

    // Fetch commits and purchases in parallel
    final results = await Future.wait([
      _client
          .from(SupabaseConfig.commitsTable)
          .select()
          .inFilter('item_uid', itemUids)
          .inFilter('status', ['active', 'purchased']),
      _client
          .from(SupabaseConfig.purchasesTable)
          .select()
          .inFilter('item_uid', itemUids)
          .inFilter('status', ['active', 'purchased']),
    ]);

    final commitsResponse = results[0];
    final purchasesResponse = results[1];

    // Create a map of item_uid -> commit
    final commitsMap = <String, Map<String, dynamic>>{};
    final userIds = <String>{};
    for (final commit in (commitsResponse as List)) {
      final itemUid = commit['item_uid'] as String;
      // Only keep first active/purchased commit per item
      if (!commitsMap.containsKey(itemUid)) {
        commitsMap[itemUid] = commit as Map<String, dynamic>;
        final userId = commit['claimed_by_user_id'] as String?;
        if (userId != null) {
          userIds.add(userId);
        }
      }
    }

    // Create a map of item_uid -> purchase
    final purchasesMap = <String, Map<String, dynamic>>{};
    for (final purchase in (purchasesResponse as List)) {
      final itemUid = purchase['item_uid'] as String;
      // Only keep first active/purchased purchase per item
      if (!purchasesMap.containsKey(itemUid)) {
        purchasesMap[itemUid] = purchase as Map<String, dynamic>;
        final userId = purchase['claimed_by_user_id'] as String?;
        if (userId != null) {
          userIds.add(userId);
        }
      }
    }

    // Fetch user data for all committers and purchasers
    final usersMap = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final usersResponse = await _client
          .from(SupabaseConfig.usersTable)
          .select('uid, display_name, avatar_url')
          .inFilter('uid', userIds.toList());
      for (final user in (usersResponse as List)) {
        usersMap[user['uid'] as String] = user as Map<String, dynamic>;
      }
    }

    // Map items with their commits and purchases
    return items.map((json) {
      final itemJson = Map<String, dynamic>.from(json);
      final itemUid = itemJson['uid'] as String;

      // Map commit data
      final commit = commitsMap[itemUid];
      if (commit != null) {
        itemJson['is_claimed'] = true;
        itemJson['claimed_by_user_id'] = commit['claimed_by_user_id'];
        itemJson['commit_uid'] = commit['uid'];
        itemJson['commit_status'] = commit['status'];
        itemJson['commit_note'] = commit['note'];
        itemJson['claimed_at'] = commit['created_at'];
        itemJson['claim_expires_at'] = commit['expires_at'];

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

      // Map purchase data
      final purchase = purchasesMap[itemUid];
      if (purchase != null) {
        itemJson['is_purchased'] = true;
        itemJson['purchased_by_user_id'] = purchase['claimed_by_user_id'];
        itemJson['purchase_uid'] = purchase['uid'];
        itemJson['purchase_note'] = purchase['note'];
        itemJson['purchased_at'] =
            purchase['purchased_at'] ?? purchase['created_at'];

        // Get display name and avatar from users map
        final userId = purchase['claimed_by_user_id'] as String?;
        if (userId != null) {
          final userData = usersMap[userId];
          if (userData != null) {
            itemJson['purchased_by_display_name'] = userData['display_name'];
            itemJson['purchased_by_avatar_url'] = userData['avatar_url'];
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

    // Get item and list info for the notification
    try {
      final itemResponse = await _client
          .from(SupabaseConfig.listItemsTable)
          .select('name, list_id, lists!inner(owner_id, title)')
          .eq('uid', itemUid)
          .maybeSingle();
      
      if (itemResponse != null) {
        final listData = itemResponse['lists'] as Map<String, dynamic>;
        final ownerId = listData['owner_id'] as String;
        final listTitle = listData['title'] as String;
        final itemName = itemResponse['name'] as String;
        
        // Get current user's display name
        final userResponse = await _client
            .from(SupabaseConfig.usersTable)
            .select('display_name')
            .eq('uid', userId)
            .maybeSingle();
        final userName = userResponse?['display_name'] as String? ?? 'Someone';
        
        // Notify the list owner (if not the same user)
        if (ownerId != userId) {
          try {
            await NotificationService().createNotification(
              userId: ownerId,
              type: 'commit_revoked',
              title: '$userName revoked commitment',
              message: 'Uncommitted from "$itemName" on your $listTitle list',
              data: {'item_uid': itemUid, 'item_name': itemName},
            );
          } catch (notifError) {
            // Log but don't fail the uncommit
            print('Failed to create revoke notification: $notifError');
          }
        }
      }
    } catch (e) {
      // Don't fail the uncommit if notification lookup fails
      print('Error getting item info for notification: $e');
    }

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

  /// Purchase an item (for gifters) - creates entry in purchases table
  Future<void> purchaseItem({required String itemUid, String? note}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // First check if a purchase already exists for this item
    final existing =
        await _client
            .from(SupabaseConfig.purchasesTable)
            .select('id')
            .eq('item_uid', itemUid)
            .maybeSingle();

    if (existing != null) {
      // Update existing purchase
      await _client
          .from(SupabaseConfig.purchasesTable)
          .update({
            'claimed_by_user_id': userId,
            'status': 'purchased',
            'purchased_at': DateTime.now().toIso8601String(),
            if (note != null && note.isNotEmpty) 'note': note,
          })
          .eq('item_uid', itemUid);
    } else {
      // Insert new purchase
      await _client.from(SupabaseConfig.purchasesTable).insert({
        'claimed_by_user_id': userId,
        'item_uid': itemUid,
        'status': 'purchased',
        'purchased_at': DateTime.now().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
    }
  }

  /// Remove purchase from an item
  Future<void> unpurchaseItem(String itemUid) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Delete purchase for this user and item
    await _client
        .from(SupabaseConfig.purchasesTable)
        .delete()
        .eq('item_uid', itemUid)
        .eq('claimed_by_user_id', userId);
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

  /// Get image URLs for items in a list (up to limit)
  /// Returns list of main image URLs (or thumbnails as fallback) for items that have images
  Future<List<String>> getListItemImages(int listId, {int limit = 5}) async {
    try {
      final response = await _client
          .from(SupabaseConfig.listItemsTable)
          .select('thumbnail_url, main_image_url')
          .eq('list_id', listId)
          .or('thumbnail_url.not.is.null,main_image_url.not.is.null')
          .limit(limit);

      return (response as List)
          .map<String?>((item) => 
              item['main_image_url'] as String? ?? item['thumbnail_url'] as String?)
          .where((url) => url != null)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching list item images: $e');
      return [];
    }
  }

  /// Get image URLs for multiple lists at once
  /// Returns a map of listId -> list of image URLs (prefers main images over thumbnails)
  Future<Map<int, List<String>>> getMultipleListImages(
    List<int> listIds, {
    int limitPerList = 5,
  }) async {
    final result = <int, List<String>>{};
    
    // Fetch images for all lists in parallel
    await Future.wait(
      listIds.map((listId) async {
        result[listId] = await getListItemImages(listId, limit: limitPerList);
      }),
    );
    
    return result;
  }
}
