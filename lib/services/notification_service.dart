import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import 'supabase_service.dart';

/// Service for managing in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _client = SupabaseService.client;
  static const String _tableName = 'notifications';

  RealtimeChannel? _channel;
  Timer? _pollingTimer;
  final _notificationsController = StreamController<List<AppNotificationModel>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  
  List<AppNotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isInitialized = false;

  /// Stream of notifications
  Stream<List<AppNotificationModel>> get notificationsStream => _notificationsController.stream;
  
  /// Stream of unread count
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  
  /// Current unread count
  int get unreadCount => _unreadCount;
  
  /// Current notifications list
  List<AppNotificationModel> get notifications => _notifications;

  /// Initialize realtime subscription for notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Load initial notifications
    await _loadNotifications();

    // Subscribe to realtime updates
    try {
      _channel = _client
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('New notification received: ${payload.newRecord}');
              final notification = AppNotificationModel.fromJson(payload.newRecord);
              _notifications.insert(0, notification);
              _unreadCount++;
              _notificationsController.add(_notifications);
              _unreadCountController.add(_unreadCount);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final updated = AppNotificationModel.fromJson(payload.newRecord);
              final index = _notifications.indexWhere((n) => n.id == updated.id);
              if (index != -1) {
                _notifications[index] = updated;
                _recalculateUnreadCount();
                _notificationsController.add(_notifications);
                _unreadCountController.add(_unreadCount);
              }
            },
          )
          .subscribe();
      debugPrint('Notification realtime subscription established');
    } catch (e) {
      debugPrint('Failed to establish realtime subscription: $e');
    }

    // Start polling as a fallback (every 30 seconds)
    _startPolling();
  }

  /// Start periodic polling for notifications
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications();
    });
  }

  /// Load notifications from database
  Future<void> _loadNotifications() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (response as List)
          .map((json) => AppNotificationModel.fromJson(json))
          .toList();
      
      _recalculateUnreadCount();
      _notificationsController.add(_notifications);
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _recalculateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.read).length;
  }

  /// Refresh notifications manually
  Future<void> refresh() async {
    await _loadNotifications();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String uid) async {
    try {
      await _client
          .from(_tableName)
          .update({'read': true})
          .eq('uid', uid);
      
      final index = _notifications.indexWhere((n) => n.uid == uid);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        _recalculateUnreadCount();
        _notificationsController.add(_notifications);
        _unreadCountController.add(_unreadCount);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from(_tableName)
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);
      
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      _unreadCount = 0;
      _notificationsController.add(_notifications);
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> delete(String uid) async {
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('uid', uid);
      
      _notifications.removeWhere((n) => n.uid == uid);
      _recalculateUnreadCount();
      _notificationsController.add(_notifications);
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Create a notification (for testing or local triggers)
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from(_tableName).insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _pollingTimer?.cancel();
    _channel?.unsubscribe();
    _notificationsController.close();
    _unreadCountController.close();
    _isInitialized = false;
  }
}

