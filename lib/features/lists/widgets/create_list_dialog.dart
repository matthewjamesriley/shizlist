import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/constants/event_suggestions.dart';
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
  final _titleFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;

  ListVisibility _visibility = ListVisibility.friends;
  bool _isLoading = false;
  DateTime? _eventDate;
  bool _isRecurring = false;
  List<EventSuggestion> _suggestions = [];
  bool _isEventSelected = false;
  bool _notifyOnCommit = true;
  bool _notifyOnPurchase = true;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    _titleFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _titleController.removeListener(_onTitleChanged);
    _titleFocusNode.removeListener(_onFocusChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (_isEventSelected) return; // Don't show suggestions after selection

    final query = _titleController.text;
    final newSuggestions = EventSuggestions.search(query);

    setState(() {
      _suggestions = newSuggestions;
    });

    if (newSuggestions.isNotEmpty && _titleFocusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onFocusChanged() {
    if (!_titleFocusNode.hasFocus) {
      _removeOverlay();
    } else if (_suggestions.isNotEmpty && !_isEventSelected) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: MediaQuery.of(context).size.width - 48,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 56),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return _SuggestionTile(
                        suggestion: suggestion,
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(EventSuggestion suggestion) {
    _removeOverlay();

    setState(() {
      _isEventSelected = true;
      _titleController.text = suggestion.name;
      _isRecurring = suggestion.isRecurringByDefault;
      _suggestions = [];

      // Auto-populate description if available
      if (suggestion.description != null) {
        _descriptionController.text = suggestion.description!;
      }

      // Auto-populate date if we know it
      if (suggestion.hasFixedDate) {
        _eventDate = suggestion.getNextDate();
      }
    });

    // Move cursor to end
    _titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: _titleController.text.length),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select event date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            textTheme: Theme.of(context).textTheme.copyWith(
              labelSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  String _formatEventDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatEventDateShort(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
          // Shared header component
          BottomSheetHeader(
            title: 'New list',
            confirmText: 'Create',
            onCancel: () => Navigator.pop(context),
            onConfirm: _createList,
            isLoading: _isLoading,
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
                    // List name
                    Text('List name', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: TextFormField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        decoration: InputDecoration(
                          hintText: 'e.g. Birthday, Wedding, Christmas etc...',
                          hintStyle: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        style: AppTypography.titleMedium,
                        onChanged: (_) {
                          // Reset event selected flag when user types
                          if (_isEventSelected) {
                            setState(() => _isEventSelected = false);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a list name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description (single line)
                    Text(
                      'Description (optional)',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'A short description...',
                        hintStyle: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 1,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 20),

                    // Event date & Recurring
                    Text(
                      'Event date (optional)',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Date picker
                        Expanded(
                          child: GestureDetector(
                            onTap: _showDatePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  PhosphorIcon(
                                    PhosphorIcons.calendarDots(),
                                    size: 20,
                                    color:
                                        _eventDate != null
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _eventDate != null
                                          ? _formatEventDateShort(_eventDate!)
                                          : 'Select date',
                                      style: AppTypography.titleMedium.copyWith(
                                        color:
                                            _eventDate != null
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (_eventDate != null)
                                    GestureDetector(
                                      onTap:
                                          () => setState(() {
                                            _eventDate = null;
                                            _isRecurring = false;
                                          }),
                                      child: PhosphorIcon(
                                        PhosphorIcons.xCircle(),
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Recurring toggle (only show if date is set)
                        if (_eventDate != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap:
                                () =>
                                    setState(() => _isRecurring = !_isRecurring),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      _isRecurring
                                          ? AppColors.primary
                                          : AppColors.divider,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color:
                                    _isRecurring
                                        ? AppColors.primary.withOpacity(0.05)
                                        : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PhosphorIcon(
                                    PhosphorIcons.arrowsClockwise(),
                                    size: 20,
                                    color:
                                        _isRecurring
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Yearly',
                                    style: AppTypography.titleMedium.copyWith(
                                      color:
                                          _isRecurring
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Visibility
                    Text('Visibility', style: AppTypography.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _VisibilityOption(
                            icon: PhosphorIcons.globeSimple(),
                            title: 'Public',
                            subtitle: 'Anyone',
                            isSelected: _visibility == ListVisibility.public,
                            onTap: () {
                              setState(
                                () => _visibility = ListVisibility.public,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VisibilityOption(
                            icon: PhosphorIcons.usersThree(),
                            title: 'Friends',
                            subtitle: 'Connected',
                            isSelected: _visibility == ListVisibility.friends,
                            onTap: () {
                              setState(
                                () => _visibility = ListVisibility.friends,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VisibilityOption(
                            icon: PhosphorIcons.lock(),
                            title: 'Private',
                            subtitle: 'Only you',
                            isSelected: _visibility == ListVisibility.private,
                            onTap: () {
                              setState(
                                () => _visibility = ListVisibility.private,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Notification preferences
                    Builder(
                      builder: (context) {
                        final isPrivate = _visibility == ListVisibility.private;
                        final commitChecked = !isPrivate && _notifyOnCommit;
                        final purchaseChecked = !isPrivate && _notifyOnPurchase;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notify me when my friends...',
                              style: AppTypography.titleMedium.copyWith(
                                color: isPrivate ? AppColors.textSecondary : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: isPrivate ? null : () => setState(() => _notifyOnCommit = !_notifyOnCommit),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: commitChecked ? AppColors.primary : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isPrivate 
                                                    ? AppColors.border.withValues(alpha: 0.5)
                                                    : (commitChecked ? AppColors.primary : AppColors.border),
                                                width: 2,
                                              ),
                                            ),
                                            child: commitChecked
                                                ? PhosphorIcon(
                                                    PhosphorIcons.check(PhosphorIconsStyle.bold),
                                                    size: 16,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              'Commit to purchase',
                                              style: AppTypography.bodyMedium.copyWith(
                                                color: isPrivate ? AppColors.textSecondary : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: isPrivate ? null : () => setState(() => _notifyOnPurchase = !_notifyOnPurchase),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: purchaseChecked ? AppColors.primary : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isPrivate 
                                                    ? AppColors.border.withValues(alpha: 0.5)
                                                    : (purchaseChecked ? AppColors.primary : AppColors.border),
                                                width: 2,
                                              ),
                                            ),
                                            child: purchaseChecked
                                                ? PhosphorIcon(
                                                    PhosphorIcons.check(PhosphorIconsStyle.bold),
                                                    size: 16,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              'Mark as purchased',
                                              style: AppTypography.bodyMedium.copyWith(
                                                color: isPrivate ? AppColors.textSecondary : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createList() async {
    // Validate title
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a list name')));
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
        notifyOnCommit: _notifyOnCommit,
        notifyOnPurchase: _notifyOnPurchase,
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

/// Suggestion tile widget with calendar icon
class _SuggestionTile extends StatelessWidget {
  final EventSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  PhosphorIconData _getIconForCategory(EventCategory category) {
    switch (category) {
      case EventCategory.birthday:
        return PhosphorIcons.cake();
      case EventCategory.wedding:
        return PhosphorIcons.star();
      case EventCategory.heart:
        return PhosphorIcons.heart();
      case EventCategory.diamond:
        return PhosphorIcons.diamond();
      case EventCategory.gift:
        return PhosphorIcons.gift();
      case EventCategory.star:
        return PhosphorIcons.star();
      case EventCategory.baby:
        return PhosphorIcons.baby();
      case EventCategory.graduation:
        return PhosphorIcons.graduationCap();
      case EventCategory.house:
        return PhosphorIcons.house();
      case EventCategory.trophy:
        return PhosphorIcons.trophy();
      case EventCategory.travel:
        return PhosphorIcons.airplane();
      case EventCategory.car:
        return PhosphorIcons.car();
      case EventCategory.camping:
        return PhosphorIcons.tent();
      case EventCategory.party:
        return PhosphorIcons.confetti();
      case EventCategory.users:
        return PhosphorIcons.usersThree();
      case EventCategory.flower:
        return PhosphorIcons.flower();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider.withOpacity(0.5)),
          ),
        ),
        child: Row(
          children: [
            // Calendar icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.calendarDots(),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PhosphorIcon(
                        _getIconForCategory(suggestion.category),
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion.name,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (suggestion.description != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2),
                      child: Text(
                        suggestion.description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (suggestion.isRecurringByDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.arrowsClockwise(),
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Annual',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected ? AppColors.claimedBackground : Colors.grey.shade100,
        ),
        child: Column(
          children: [
            PhosphorIcon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
