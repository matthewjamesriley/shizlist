import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/models.dart';
import '../core/constants/supabase_config.dart';

/// Service for managing list items
class ItemService {
  final SupabaseClient _client = SupabaseService.client;
  final _uuid = const Uuid();

  /// Get all items for a list
  Future<List<ListItem>> getListItems(int listId) async {
    final response = await _client
        .from(SupabaseConfig.listItemsTable)
        .select()
        .eq('list_id', listId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ListItem.fromJson(json))
        .toList();
  }

  /// Get a single item by UID
  Future<ListItem?> getItemByUid(String uid) async {
    final response = await _client
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
    required ItemCategory category,
    ItemPriority priority = ItemPriority.medium,
    int quantity = 1,
  }) async {
    final uid = _uuid.v4();
    final response = await _client
        .from(SupabaseConfig.listItemsTable)
        .insert({
          'uid': uid,
          'list_id': listId,
          'name': name,
          'description': description,
          'price': price,
          'currency': currency ?? 'USD',
          'retailer_url': retailerUrl,
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
    final response = await _client
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
          'priority': ItemPriority.medium.name,
          'quantity': 1,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return ListItem.fromJson(response);
  }

  /// Update an existing item
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
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (currency != null) updates['currency'] = currency;
    if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
    if (mainImageUrl != null) updates['main_image_url'] = mainImageUrl;
    if (retailerUrl != null) updates['retailer_url'] = retailerUrl;
    if (category != null) updates['category'] = category.name;
    if (priority != null) updates['priority'] = priority.name;
    if (quantity != null) updates['quantity'] = quantity;

    final response = await _client
        .from(SupabaseConfig.listItemsTable)
        .update(updates)
        .eq('uid', uid)
        .select()
        .single();

    return ListItem.fromJson(response);
  }

  /// Delete an item
  Future<void> deleteItem(String uid) async {
    await _client
        .from(SupabaseConfig.listItemsTable)
        .delete()
        .eq('uid', uid);
  }

  /// Claim an item (for gifters)
  Future<void> claimItem({
    required int itemId,
    DateTime? expiresAt,
    String? note,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Use the claim_item database function for safe transactional claim
    await _client.rpc(SupabaseConfig.claimItemFunction, params: {
      'p_item_id': itemId,
      'p_user_id': userId,
      'p_expires_at': expiresAt?.toIso8601String(),
      'p_note': note,
    });
  }

  /// Unclaim an item
  Future<void> unclaimItem(int itemId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _client.rpc(SupabaseConfig.unclaimItemFunction, params: {
      'p_item_id': itemId,
      'p_user_id': userId,
    });
  }

  /// Mark claim as purchased
  Future<void> markAsPurchased(int claimId) async {
    await _client
        .from(SupabaseConfig.claimsTable)
        .update({
          'status': 'purchased',
          'purchased_at': DateTime.now().toIso8601String(),
        })
        .eq('id', claimId);
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

    return (response as List)
        .map((json) => ListItem.fromJson(json))
        .toList();
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


