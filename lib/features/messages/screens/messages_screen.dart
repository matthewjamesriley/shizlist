import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Messages screen for group conversations about shared lists
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Sample conversations data
  final List<_Conversation> _conversations = [
    _Conversation(
      id: '1',
      listTitle: "Sarah's Birthday Wishlist",
      lastMessage: "I'll get the cooking class tickets!",
      lastSender: 'Mike',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      unreadCount: 2,
      participantCount: 4,
    ),
    _Conversation(
      id: '2',
      listTitle: 'Holiday Gift Exchange',
      lastMessage: "Don't forget the \$50 limit",
      lastSender: 'Emily',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      participantCount: 6,
    ),
    _Conversation(
      id: '3',
      listTitle: "Mom's Anniversary Present",
      lastMessage: 'Perfect! I claimed the spa package',
      lastSender: 'You',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      participantCount: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _buildConversationTile(conversation);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.claimedBackground,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Messages Yet',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'When you share lists with others, you can coordinate gift-giving here.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(_Conversation conversation) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
            radius: 28,
            child: const Icon(
              Icons.people,
              color: AppColors.primary,
            ),
          ),
          if (conversation.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        conversation.listTitle,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: conversation.unreadCount > 0
              ? FontWeight.w700
              : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${conversation.lastSender}: ${conversation.lastMessage}',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: conversation.unreadCount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.group,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 4),
              Text(
                '${conversation.participantCount} participants',
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ],
      ),
      trailing: Text(
        _formatTimestamp(conversation.timestamp),
        style: AppTypography.labelSmall.copyWith(
          color: conversation.unreadCount > 0
              ? AppColors.primary
              : AppColors.textHint,
        ),
      ),
      onTap: () => _openConversation(conversation),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  void _openConversation(_Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ConversationDetailScreen(
          conversation: conversation,
        ),
      ),
    );
  }
}

class _Conversation {
  final String id;
  final String listTitle;
  final String lastMessage;
  final String lastSender;
  final DateTime timestamp;
  final int unreadCount;
  final int participantCount;

  _Conversation({
    required this.id,
    required this.listTitle,
    required this.lastMessage,
    required this.lastSender,
    required this.timestamp,
    required this.unreadCount,
    required this.participantCount,
  });
}

/// Conversation detail screen
class _ConversationDetailScreen extends StatefulWidget {
  final _Conversation conversation;

  const _ConversationDetailScreen({
    required this.conversation,
  });

  @override
  State<_ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<_ConversationDetailScreen> {
  final _messageController = TextEditingController();
  final List<_Message> _messages = [
    _Message(
      sender: 'Mike',
      content: "Hey everyone! Let's coordinate gifts for Sarah",
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isMe: false,
    ),
    _Message(
      sender: 'Emily',
      content: "Great idea! I was thinking of getting the cooking class",
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      isMe: false,
    ),
    _Message(
      sender: 'You',
      content: "I'll take the AirPods then!",
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isMe: true,
    ),
    _Message(
      sender: 'Mike',
      content: "I'll get the cooking class tickets!",
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isMe: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.listTitle,
              style: AppTypography.titleMedium,
            ),
            Text(
              '${widget.conversation.participantCount} participants',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show conversation info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!message.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                message.sender,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: message.isMe
                  ? AppColors.primary
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: message.isMe ? const Radius.circular(4) : null,
                bottomLeft: !message.isMe ? const Radius.circular(4) : null,
              ),
            ),
            child: Text(
              message.content,
              style: AppTypography.bodyMedium.copyWith(
                color: message.isMe
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(_Message(
        sender: 'You',
        content: _messageController.text.trim(),
        timestamp: DateTime.now(),
        isMe: true,
      ));
    });

    _messageController.clear();
  }
}

class _Message {
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  _Message({
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}

