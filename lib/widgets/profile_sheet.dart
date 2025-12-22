import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/image_upload_service.dart';
import '../services/user_settings_service.dart';
import 'app_notification.dart';
import 'bottom_sheet_header.dart';
import 'dart:ui';

/// Profile editing sheet
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => const ProfileSheet(),
    );
  }

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final _authService = AuthService();
  final _imageUploadService = ImageUploadService();
  final _nameController = TextEditingController();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImageFile;
  bool _removeImage = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile?.displayName ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.error(context, 'Failed to load profile');
      }
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
        });
        AppNotification.success(context, 'Email refreshed');
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to refresh');
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    File? file;
    if (source == ImageSource.gallery) {
      file = await _imageUploadService.pickFromGallery();
    } else {
      file = await _imageUploadService.pickFromCamera();
    }

    if (file != null && mounted) {
      setState(() {
        _selectedImageFile = file;
        _removeImage = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      String? avatarUrl;

      // Upload new image if selected
      if (_selectedImageFile != null) {
        setState(() {
          _uploadProgress = 0;
          _uploadStatus = 'Uploading image...';
        });

        final result = await _imageUploadService.processAndUpload(
          _selectedImageFile!,
          onProgress: (progress, status) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
                _uploadStatus = status;
              });
            }
          },
        );

        if (result != null) {
          avatarUrl = result.mainImageUrl;
        }
      } else if (_removeImage) {
        // Set to empty string to clear the avatar
        avatarUrl = '';
      }

      // Update profile
      final updatedProfile = await _authService.updateUserProfile(
        displayName:
            _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : null,
        avatarUrl: avatarUrl,
      );

      // Reload user settings to reflect changes
      await UserSettingsService().loadSettings();

      if (mounted) {
        AppNotification.success(context, 'Profile updated');
        Navigator.pop(context, updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.error(context, 'Failed to update profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            title: 'Edit profile',
            confirmText: 'Save',
            onCancel: () => Navigator.pop(context),
            onConfirm: _saveProfile,
            isLoading: _isSaving,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => _showImagePicker(),
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textPrimary,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(child: _buildAvatarContent()),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: PhosphorIcon(
                                PhosphorIcons.camera(),
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Tap to change photo',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),

                    // Upload progress
                    if (_isSaving && _selectedImageFile != null) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadStatus,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Name field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Display name',
                        style: AppTypography.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: AppTypography.bodyLarge,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 24),

                    // Email
                    Row(
                      children: [
                        Text('Email', style: AppTypography.titleMedium),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _refreshProfile,
                          child: PhosphorIcon(
                            PhosphorIcons.arrowClockwise(),
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _profile?.email ?? '',
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          // Only show change email for email/password users
                          if (_authService.isEmailPasswordUser)
                            GestureDetector(
                              onTap: _showChangeEmailDialog,
                              child: Text(
                                'Change',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (_removeImage) {
      return _buildInitials();
    }

    if (_selectedImageFile != null) {
      return Image.file(
        _selectedImageFile!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    }

    if (_profile?.avatarUrl != null) {
      return Image.network(
        _profile!.avatarUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) => _buildInitials(),
      );
    }

    return _buildInitials();
  }

  Widget _buildInitials() {
    return Container(
      color: Colors.white,
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.user(),
          size: 56,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  bool get _hasImage =>
      !_removeImage &&
      (_selectedImageFile != null || _profile?.avatarUrl != null);

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChanging = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: FadeTransition(
            opacity: animation,
            child: StatefulBuilder(
              builder:
                  (context, setDialogState) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade800, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Black header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          color: Colors.black,
                          child: Text(
                            'Change email address',
                            style: AppTypography.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enter your new email address. We\'ll send a confirmation link to your current email to verify the change.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Current email:',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _profile?.email ?? '',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'New email address',
                                    hintText: 'Enter new email',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    final currentEmail =
                                        (_profile?.email ?? '').toLowerCase();
                                    if (value.toLowerCase() == currentEmail) {
                                      return 'New email must be different';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      isChanging
                                          ? null
                                          : () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: BorderSide(color: AppColors.divider),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      isChanging
                                          ? null
                                          : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            final newEmail =
                                                emailController.text.trim();

                                            setDialogState(
                                              () => isChanging = true,
                                            );

                                            try {
                                              // First check if email already exists
                                              final exists = await _authService
                                                  .emailExists(newEmail);
                                              if (exists) {
                                                setDialogState(
                                                  () => isChanging = false,
                                                );
                                                if (mounted) {
                                                  AppNotification.error(
                                                    context,
                                                    'This email is already in use',
                                                  );
                                                }
                                                return;
                                              }

                                              // Email doesn't exist, proceed with change request
                                              final currentEmail =
                                                  _profile?.email ?? '';
                                              await _authService.updateEmail(
                                                newEmail,
                                              );
                                              if (mounted) {
                                                Navigator.pop(dialogContext);
                                                _showEmailChangeConfirmation(
                                                  newEmail,
                                                  currentEmail,
                                                );
                                              }
                                            } catch (e) {
                                              setDialogState(
                                                () => isChanging = false,
                                              );
                                              if (mounted) {
                                                AppNotification.error(
                                                  context,
                                                  'Failed to change email',
                                                );
                                              }
                                            }
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child:
                                      isChanging
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            'Send',
                                            style: AppTypography.titleMedium
                                                .copyWith(color: Colors.white),
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }

  void _showEmailChangeConfirmation(String newEmail, String currentEmail) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Black header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    color: Colors.black,
                    child: Text(
                      'Check Your Email',
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.envelopeSimple(),
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We\'ve sent a confirmation link to your current email:',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentEmail,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Click the link in the email to confirm the change to $newEmail. Your email won\'t change until you confirm.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Got it',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Choose photo', style: AppTypography.titleLarge),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ImagePickerOption(
                          icon: PhosphorIcons.image(),
                          label: 'Gallery',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ImagePickerOption(
                          icon: PhosphorIcons.camera(),
                          label: 'Camera',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_hasImage) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedImageFile = null;
                            _removeImage = true;
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: Text(
                          'Remove photo',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            PhosphorIcon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.bodyLarge),
          ],
        ),
      ),
    );
  }
}
