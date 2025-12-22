import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Contacts screen for managing friends and shared list participants
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();

  // Sample contacts data
  final List<_Contact> _contacts = [
    _Contact(
      name: 'Sarah Johnson',
      email: 'sarah.j@email.com',
      avatarColor: AppColors.categoryEvents,
    ),
    _Contact(
      name: 'Mike Wilson',
      email: 'mike.w@email.com',
      avatarColor: AppColors.categoryTrips,
    ),
    _Contact(
      name: 'Emily Chen',
      email: 'emily.c@email.com',
      avatarColor: AppColors.categoryStuff,
    ),
    _Contact(
      name: 'David Brown',
      email: 'david.b@email.com',
      avatarColor: AppColors.categoryCrafted,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchController.clear());
                        },
                      )
                      : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Contacts list
        Expanded(
          child:
              _contacts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                    itemCount: _contacts.length + 1, // +1 for add button
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildAddContactTile();
                      }

                      final contact = _contacts[index - 1];
                      return _buildContactTile(contact);
                    },
                  ),
        ),
      ],
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
                Icons.people_outline,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('No Contacts Yet', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add friends and family to easily share your wish lists with them.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddContactTile() {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.person_add, color: AppColors.primary),
      ),
      title: Text(
        'Add New Contact',
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: const Text('Invite someone to ShizList'),
      onTap: _addContact,
    );
  }

  Widget _buildContactTile(_Contact contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.avatarColor.withValues(alpha: 0.2),
        child: Text(
          contact.initials,
          style: AppTypography.titleMedium.copyWith(color: contact.avatarColor),
        ),
      ),
      title: Text(contact.name, style: AppTypography.bodyLarge),
      subtitle: Text(contact.email, style: AppTypography.bodySmall),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _handleContactAction(action, contact),
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'message',
                child: ListTile(
                  leading: Icon(Icons.message),
                  title: Text('Message'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading: Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Remove',
                    style: TextStyle(color: AppColors.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
      ),
      onTap: () => _viewContact(contact),
    );
  }

  void _addContact() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter email address',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Name (optional)',
                    hintText: 'Enter name',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation sent!')),
                  );
                },
                child: const Text('Send Invite'),
              ),
            ],
          ),
    );
  }

  void _viewContact(_Contact contact) {
    // TODO: Navigate to contact detail
  }

  void _handleContactAction(String action, _Contact contact) {
    switch (action) {
      case 'share':
        // TODO: Share list with contact
        break;
      case 'message':
        // TODO: Open message with contact
        break;
      case 'remove':
        _confirmRemoveContact(contact);
        break;
    }
  }

  void _confirmRemoveContact(_Contact contact) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Contact'),
            content: Text('Remove ${contact.name} from your contacts?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _contacts.remove(contact);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed ${contact.name}')),
                  );
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );
  }
}

class _Contact {
  final String name;
  final String email;
  final Color avatarColor;

  _Contact({
    required this.name,
    required this.email,
    required this.avatarColor,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
