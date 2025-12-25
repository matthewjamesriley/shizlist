import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/wish_list.dart';

/// Share screen for sharing lists and inviting users
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  WishList? _selectedList;

  // Sample lists
  final List<WishList> _lists = [
    WishList(
      id: 1,
      uid: 'abc123',
      ownerId: 'user-1',
      title: 'My Birthday Wishlist',
      visibility: ListVisibility.public,
      createdAt: DateTime.now(),
      itemCount: 12,
      claimedCount: 4,
    ),
    WishList(
      id: 2,
      uid: 'def456',
      ownerId: 'user-1',
      title: 'Holiday Gift Ideas',
      visibility: ListVisibility.private,
      createdAt: DateTime.now(),
      itemCount: 8,
      claimedCount: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (_lists.isNotEmpty) {
      _selectedList = _lists.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // List selector
          Text('Select a List to Share', style: AppTypography.titleMedium),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<WishList>(
                value: _selectedList,
                isExpanded: true,
                items:
                    _lists.map((list) {
                      return DropdownMenuItem(
                        value: list,
                        child: Row(
                          children: [
                            PhosphorIcon(
                              list.isPublic
                                  ? PhosphorIcons.usersThree()
                                  : PhosphorIcons.lock(),
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                list.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (list) {
                  setState(() => _selectedList = list);
                },
              ),
            ),
          ),

          if (_selectedList != null) ...[
            const SizedBox(height: 32),

            // Share link section
            _buildSectionHeader(icon: Icons.link, title: 'Share Link'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedList!.shareUrl,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareLink,
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // QR Code section
            _buildSectionHeader(icon: Icons.qr_code, title: 'QR Code'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // QR Code placeholder
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 8),
                          Text('QR Code', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Download QR code
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download QR Code'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Invite by email section
            _buildSectionHeader(
              icon: Icons.email_outlined,
              title: 'Invite by Email',
            ),
            const SizedBox(height: 12),

            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sendInvite,
              child: const Text('Send Invite'),
            ),

            const SizedBox(height: 24),

            // Visibility setting
            _buildSectionHeader(
              icon: Icons.visibility_outlined,
              title: 'List Visibility',
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    _selectedList!.isPublic
                        ? PhosphorIcons.usersThree()
                        : PhosphorIcons.lock(),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedList!.isPublic ? 'Public' : 'Private',
                          style: AppTypography.titleSmall,
                        ),
                        Text(
                          _selectedList!.isPublic
                              ? 'Anyone with the link can view this list'
                              : 'Only people you invite can view this list',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _selectedList!.isPublic,
                    onChanged: (value) {
                      // TODO: Update visibility
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'List is now ${value ? 'public' : 'private'}',
                          ),
                        ),
                      );
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.titleSmall),
      ],
    );
  }

  Future<void> _copyLink() async {
    if (_selectedList == null) return;

    // Clear clipboard first to avoid iOS bplist bug mixing with share data
    await Clipboard.setData(const ClipboardData(text: ''));
    await Future.delayed(const Duration(milliseconds: 50));
    await Clipboard.setData(ClipboardData(text: _selectedList!.shareUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareLink() {
    if (_selectedList == null) return;

    // TODO: Use share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: ${_selectedList!.shareUrl}')),
    );
  }

  void _sendInvite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invitation sent!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
