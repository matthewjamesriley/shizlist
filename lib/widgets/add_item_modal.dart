import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'category_grid.dart';
import '../models/list_item.dart';

/// Add item modal matching ShizList design
/// Shows three main options: Search Amazon, Quick Add, Paste Link
class AddItemModal extends StatelessWidget {
  final String listTitle;
  final VoidCallback onSearchAmazon;
  final VoidCallback onQuickAdd;
  final VoidCallback onPasteLink;

  const AddItemModal({
    super.key,
    required this.listTitle,
    required this.onSearchAmazon,
    required this.onQuickAdd,
    required this.onPasteLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Add Item to ',
                  style: AppTypography.titleMedium,
                ),
                Text(
                  listTitle,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 16,
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Search on Amazon - Teal
                _ActionButton(
                  icon: Icons.search,
                  label: 'Search on Amazon',
                  color: AppColors.primary,
                  onPressed: onSearchAmazon,
                ),
                const SizedBox(height: 12),
                
                // Quick Add Manually - Orange
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Quick Add Manually',
                  color: AppColors.secondary,
                  onPressed: onQuickAdd,
                ),
                const SizedBox(height: 12),
                
                // Paste Product Link - Blue outline
                _ActionButton(
                  icon: Icons.link,
                  label: 'Paste Product Link',
                  color: AppColors.tertiary,
                  outlined: true,
                  onPressed: onPasteLink,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Category grid preview (faded)
          Opacity(
            opacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CategoryGrid(
                onCategorySelected: (_) {},
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.buttonText.copyWith(color: color),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.buttonText),
        ],
      ),
    );
  }
}

/// Quick add form sheet
class QuickAddForm extends StatefulWidget {
  final int listId;
  final Function(String name, ItemCategory category, double? price)? onSave;

  const QuickAddForm({
    super.key,
    required this.listId,
    this.onSave,
  });

  @override
  State<QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends State<QuickAddForm> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  ItemCategory _selectedCategory = ItemCategory.stuff;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Center(
              child: Text(
                'Quick Add Manually',
                style: AppTypography.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            
            // Item Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'Cats Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Category selection
            Text('Category', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.displayName),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // Price (optional)
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Price (Optional)',
                hintText: '\$0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Add to List button
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(_priceController.text);
                widget.onSave?.call(
                  _nameController.text,
                  _selectedCategory,
                  price,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Add to List'),
            ),
          ],
        ),
      ),
    );
  }
}

