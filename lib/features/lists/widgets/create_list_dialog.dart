import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/wish_list.dart';

/// Dialog for creating a new wish list
class CreateListDialog extends StatefulWidget {
  const CreateListDialog({super.key});

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();

  /// Show the create list dialog as a bottom sheet
  static Future<WishList?> show(BuildContext context) {
    return showModalBottomSheet<WishList>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => const CreateListDialog(),
    );
  }
}

class _CreateListDialogState extends State<CreateListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  ListVisibility _visibility = ListVisibility.private;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
          // Header with black background
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Title - centered
                Text(
                  'New list',
                  style: AppTypography.titleLarge.copyWith(color: Colors.white),
                ),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    // Create button - prominent pill style
                    GestureDetector(
                      onTap: _isLoading ? null : _createList,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  'Create',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'List name'),
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      style: AppTypography.titleMedium,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a list name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 3,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 32),

                    Text('Visibility', style: AppTypography.titleMedium),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _VisibilityOption(
                            icon: Icons.lock_outline,
                            title: 'Private',
                            subtitle: 'Only shared users',
                            isSelected: _visibility == ListVisibility.private,
                            onTap: () {
                              setState(
                                () => _visibility = ListVisibility.private,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _VisibilityOption(
                            icon: Icons.public,
                            title: 'Public',
                            subtitle: 'Anyone with link',
                            isSelected: _visibility == ListVisibility.public,
                            onTap: () {
                              setState(
                                () => _visibility = ListVisibility.public,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createList() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Create list via ListService
    final list = WishList(
      id: DateTime.now().millisecondsSinceEpoch,
      uid: const Uuid().v4(),
      ownerId: 'current-user', // TODO: Get from auth
      title: _titleController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      visibility: _visibility,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, list);
  }
}

class _VisibilityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color:
              isSelected ? AppColors.claimedBackground : Colors.grey.shade100,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
