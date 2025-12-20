import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/list_item.dart';
import '../../../services/user_settings_service.dart';

/// Full screen for adding items (alternative to modal)
class AddItemScreen extends StatefulWidget {
  final int listId;

  const AddItemScreen({super.key, required this.listId});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  final _amazonSearchController = TextEditingController();

  ItemCategory _selectedCategory = ItemCategory.stuff;
  ItemPriority _selectedPriority = ItemPriority.medium;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    _amazonSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Quick Add'),
            Tab(text: 'Amazon'),
            Tab(text: 'Paste Link'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickAddTab(),
          _buildAmazonSearchTab(),
          _buildPasteLinkTab(),
        ],
      ),
    );
  }

  Widget _buildQuickAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'What do you want?',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add more details (optional)',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Price and URL row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      hintText: '0.00',
                      prefixText: '${UserSettingsService().currencySymbol} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Item link',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category selection
            Text('Category', style: AppTypography.labelLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  ItemCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: 16,
                            color:
                                isSelected ? AppColors.primary : category.color,
                          ),
                          const SizedBox(width: 6),
                          Text(category.displayName),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),

            // Priority selection
            Text('Priority', style: AppTypography.labelLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children:
                  ItemPriority.values.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    return ChoiceChip(
                      label: Text(priority.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPriority = priority);
                        }
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmazonSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _amazonSearchController,
            decoration: InputDecoration(
              hintText: 'Search Amazon...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _amazonSearchController.clear(),
              ),
            ),
            onSubmitted: _searchAmazon,
          ),
          const SizedBox(height: 24),

          // Search results placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for products on Amazon',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items will be added with affiliate links',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteLinkTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Paste product link here...',
              prefixIcon: Icon(Icons.link),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              // TODO: Parse link and extract product info
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Fetch Product Details'),
          ),
          const SizedBox(height: 24),

          // Preview placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.preview, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text(
                      'Product preview will appear here',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _searchAmazon(String query) {
    if (query.isEmpty) return;
    // TODO: Implement Amazon PA-API search
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Searching for "$query"...')));
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Save item via ItemService
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${_nameController.text}"')),
        );
      }
    });
  }
}
