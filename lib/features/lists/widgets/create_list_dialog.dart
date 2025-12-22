import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/wish_list.dart';
import '../../../services/list_service.dart';
import '../../../widgets/bottom_sheet_header.dart';

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
  ListVisibility _visibility = ListVisibility.public;
  bool _isLoading = false;
  DateTime? _eventDate;
  bool _isRecurring = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatEventDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
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
            // Shared header component
            BottomSheetHeader(
              title: 'New list',
              confirmText: 'Create',
              onCancel: () => Navigator.pop(context),
              onConfirm: _createList,
              isLoading: _isLoading,
            ),

            // Tabs
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: AppTypography.titleMedium,
                unselectedLabelStyle: AppTypography.titleMedium,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'List details'),
                  Tab(text: 'Set date'),
                ],
              ),
            ),

            // Tab content
            Flexible(
              child: TabBarView(
                children: [
                  // Tab 1: List details
                  SingleChildScrollView(
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
                          Text('List name', style: AppTypography.titleMedium),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText:
                                  'e.g. Gift ideas, Wish list, Things to do etc...',
                            ),
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

                          Text(
                            'Description (optional)',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              hintText:
                                  'e.g. These are a few of my favourite things',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 2,
                            maxLines: 3,
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: 24),

                          Text('Visibility', style: AppTypography.titleMedium),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _VisibilityOption(
                                  icon: PhosphorIcons.usersThree(),
                                  title: 'Public',
                                  subtitle: 'Anyone with link',
                                  isSelected:
                                      _visibility == ListVisibility.public,
                                  onTap: () {
                                    setState(
                                      () => _visibility = ListVisibility.public,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _VisibilityOption(
                                  icon: PhosphorIcons.lock(),
                                  title: 'Private',
                                  subtitle: 'Only shared users',
                                  isSelected:
                                      _visibility == ListVisibility.private,
                                  onTap: () {
                                    setState(
                                      () =>
                                          _visibility = ListVisibility.private,
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

                  // Tab 2: Set date
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event date section
                        Text(
                          'Event date',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set a date for birthdays, weddings, holidays, etc.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date picker row
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _eventDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primary,
                                      onPrimary: Colors.white,
                                      surface: AppColors.surface,
                                      onSurface: AppColors.textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => _eventDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.divider),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.calendarDots(),
                                  size: 24,
                                  color: _eventDate != null
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _eventDate != null
                                        ? _formatEventDate(_eventDate!)
                                        : 'Select a date',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: _eventDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (_eventDate != null)
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _eventDate = null;
                                      _isRecurring = false;
                                    }),
                                    child: PhosphorIcon(
                                      PhosphorIcons.xCircle(),
                                      size: 24,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Recurring section
                        Text(
                          'Recurring',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enable for events that happen every year',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recurring toggle
                        GestureDetector(
                          onTap: () => setState(
                            () => _isRecurring = !_isRecurring,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isRecurring
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: _isRecurring ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: _isRecurring
                                  ? AppColors.primary.withOpacity(0.05)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.arrowsClockwise(),
                                  size: 24,
                                  color: _isRecurring
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recurring annually',
                                        style: AppTypography.titleSmall.copyWith(
                                          color: _isRecurring
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'For birthdays and yearly events',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PhosphorIcon(
                                  _isRecurring
                                      ? PhosphorIcons.checkCircle(
                                          PhosphorIconsStyle.fill,
                                        )
                                      : PhosphorIcons.circle(),
                                  size: 24,
                                  color: _isRecurring
                                      ? AppColors.primary
                                      : AppColors.divider,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Info about event date
                        if (_eventDate != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
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
                                    _isRecurring
                                        ? 'This date will repeat every year'
                                        : 'This is a one-time event',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createList() async {
    // Validate title - form might not be visible if on Set date tab
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final listService = ListService();
      final list = await listService.createList(
        title: _titleController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        visibility: _visibility,
        eventDate: _eventDate,
        isRecurring: _isRecurring,
      );

      if (mounted) {
        Navigator.pop(context, list);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating list: $e')));
      }
    }
  }
}

class _VisibilityOption extends StatelessWidget {
  final PhosphorIconData icon;
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
            PhosphorIcon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
