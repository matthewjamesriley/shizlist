import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/app_notification.dart';
import '../../../services/notification_service.dart';

/// Screen for displaying user notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Mark all as read when opening
    _notificationService.markAllAsRead();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'commit':
        return PhosphorIcons.handshake();
      case 'purchase':
        return PhosphorIcons.shoppingCart();
      case 'friend_request':
        return PhosphorIcons.userPlus();
      case 'friend_accepted':
        return PhosphorIcons.users();
      case 'list_shared':
        return PhosphorIcons.share();
      default:
        return PhosphorIcons.bell();
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'commit':
        return Colors.amber.shade700;
      case 'purchase':
        return AppColors.primary;
      case 'friend_request':
        return Colors.blue;
      case 'friend_accepted':
        return Colors.green;
      case 'list_shared':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notificationService.notifications.isNotEmpty)
            TextButton(
              onPressed: () => _notificationService.markAllAsRead(),
              child: Text(
                'Mark all read',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.notifications,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.bellSlash(),
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When friends interact with your lists,\nyou\'ll see it here',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _notificationService.refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationTile(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(AppNotificationModel notification) {
    return Dismissible(
      key: Key(notification.uid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const PhosphorIcon(
          PhosphorIconsBold.trash,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _notificationService.delete(notification.uid),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getColorForType(notification.type).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: PhosphorIcon(
              _getIconForType(notification.type),
              size: 24,
              color: _getColorForType(notification.type),
            ),
          ),
        ),
        title: Text(
          notification.title,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.message != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.message!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: !notification.read
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          // Mark as read
          if (!notification.read) {
            _notificationService.markAsRead(notification.uid);
          }
          // TODO: Navigate to relevant screen based on notification.data
        },
      ),
    );
  }
}

