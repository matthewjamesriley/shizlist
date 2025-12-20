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
                            child: ClipOval(
                              child: _buildAvatarContent(),
                            ),
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
                        color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Name field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Display name', style: AppTypography.titleMedium),
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

                    // Email (read-only)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Email', style: AppTypography.titleMedium),
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
                      child: Text(
                        _profile?.email ?? '',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
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

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose photo',
                style: AppTypography.titleLarge,
              ),
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
            PhosphorIcon(
              icon,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

