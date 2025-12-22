import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/invite_link.dart';
import '../../../models/wish_list.dart';
import '../../../services/invite_service.dart';
import '../../../services/list_service.dart';
import '../../../widgets/app_notification.dart';

/// Invite screen for inviting friends to ShizList
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final InviteService _inviteService = InviteService();
  final ListService _listService = ListService();

  List<WishList> _lists = [];
  WishList? _selectedList;
  InviteLink? _currentInvite;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _listService.getUserLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.error(context, 'Failed to load lists');
      }
    }
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isGenerating = true);
    try {
      final invite = await _inviteService.createInviteLink(
        listId: _selectedList?.id,
      );
      if (mounted) {
        setState(() {
          _currentInvite = invite;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        AppNotification.error(context, 'Failed to generate invite link');
      }
    }
  }

  void _copyLink() {
    if (_currentInvite == null) return;
    Clipboard.setData(ClipboardData(text: _currentInvite!.inviteUrl));
    AppNotification.success(context, 'Link copied to clipboard');
  }

  void _shareLink() {
    if (_currentInvite == null) return;

    String message = 'Join me on ShizList!';
    if (_selectedList != null) {
      message = 'Join my list "${_selectedList!.title}" on ShizList!';
    }

    Share.share(
      '$message\n\n${_currentInvite!.inviteUrl}',
      subject: 'ShizList Invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const SizedBox(height: 0),

          // List selector (optional)
          Text(
            'Share a list (optional)',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<WishList?>(
                value: _selectedList,
                isExpanded: true,
                hint: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.listBullets(),
                      size: 20,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No list selected (app invite only)',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                items: [
                  // "None" option
                  DropdownMenuItem<WishList?>(
                    value: null,
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.prohibit(),
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'No list (app invite only)',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // User's lists
                  ..._lists.map((list) {
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
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (list) {
                  setState(() {
                    _selectedList = list;
                    _currentInvite = null; // Reset invite when list changes
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Generate button
          if (_currentInvite == null) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateInviteLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child:
                    _isGenerating
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(PhosphorIcons.link(), size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Generate invite link',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ] else ...[
            // Invite link generated - show share options
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  // Share and Copy buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _copyLink,
                            icon: PhosphorIcon(PhosphorIcons.copy(), size: 20),
                            label: Text(
                              'Copy',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _shareLink,
                            icon: PhosphorIcon(
                              PhosphorIcons.shareFat(),
                              size: 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Share',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _currentInvite!.inviteUrl,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Scan to join',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Generate new link button
                  TextButton(
                    onPressed: () {
                      setState(() => _currentInvite = null);
                    },
                    child: Text(
                      'Generate new link',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.info(),
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedList != null
                        ? 'Your friend will be added to "${_selectedList!.title}" when they accept the invite.'
                        : 'Your friend will be invited to join ShizList. You can share lists with them later.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
