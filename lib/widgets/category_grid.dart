import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/list_item.dart';

/// Category grid matching ShizList design with purple icons
class CategoryGrid extends StatelessWidget {
  final ItemCategory? selectedCategory;
  final Function(ItemCategory) onCategorySelected;
  final bool showAllCategories;

  const CategoryGrid({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
    this.showAllCategories = true,
  });

  @override
  Widget build(BuildContext context) {
    final categories =
        showAllCategories
            ? ItemCategory.values
            : ItemCategory.values.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = selectedCategory == category;

        return _CategoryTile(
          category: category,
          isSelected: isSelected,
          onTap: () => onCategorySelected(category),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ItemCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.categoryPurpleLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.categoryPurple
                    : AppColors.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 32,
              color: AppColors.categoryPurple,
            ),
            const SizedBox(height: 8),
            Text(
              category.displayName,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ItemCategory category) {
    switch (category) {
      case ItemCategory.stuff:
        return Icons.home_outlined;
      case ItemCategory.events:
        return Icons.event_outlined;
      case ItemCategory.trips:
        return Icons.flight_outlined;
      case ItemCategory.crafted:
        return Icons.handyman_outlined;
      case ItemCategory.meals:
        return Icons.restaurant_outlined;
      case ItemCategory.other:
        return Icons.more_horiz;
    }
  }
}

/// Horizontal scrollable category chips
class CategoryChips extends StatelessWidget {
  final ItemCategory? selectedCategory;
  final Function(ItemCategory?) onCategorySelected;

  const CategoryChips({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selectedCategory == null,
              onSelected: (_) => onCategorySelected(null),
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color:
                    selectedCategory == null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                fontWeight:
                    selectedCategory == null
                        ? FontWeight.w600
                        : FontWeight.normal,
              ),
            ),
          ),
          // Category chips
          ...ItemCategory.values.map((category) {
            final isSelected = selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.displayName),
                selected: isSelected,
                onSelected: (_) => onCategorySelected(category),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
