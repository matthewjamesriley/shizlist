import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/currency.dart';
import '../../../services/user_settings_service.dart';
import '../../../widgets/app_notification.dart';

/// Settings screen with currency selection
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userSettingsService = UserSettingsService();
  final _searchController = TextEditingController();
  Currency? _selectedCurrency;
  List<Currency> _filteredCurrencies = Currency.all;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = _userSettingsService.currency;
    _searchController.addListener(_filterCurrencies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = Currency.all;
      } else {
        _filteredCurrencies =
            Currency.all.where((currency) {
              return currency.country.toLowerCase().contains(query) ||
                  currency.name.toLowerCase().contains(query) ||
                  currency.code.toLowerCase().contains(query);
            }).toList();
      }
    });
  }

  Future<void> _saveCurrency(Currency currency) async {
    if (_isSaving) return;

    setState(() {
      _selectedCurrency = currency;
      _isSaving = true;
    });

    try {
      await _userSettingsService.updateCurrency(currency.code);
      if (mounted) {
        AppNotification.success(
          context,
          'Currency updated to ${currency.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Failed to update currency');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTypography.titleMedium.copyWith(color: Colors.white),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Country / Currency',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your preferred currency for displaying prices',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search country or currency...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PhosphorIcon(
                      PhosphorIcons.magnifyingGlass(),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Currency list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected = currency.code == _selectedCurrency?.code;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color:
                        isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _saveCurrency(currency),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Flag emoji
                            Text(
                              currency.flag,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 16),

                            // Country and currency name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currency.country,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    currency.name,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Currency code badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                currency.code,
                                style: AppTypography.labelLarge.copyWith(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            // Check icon
                            if (isSelected) ...[
                              const SizedBox(width: 12),
                              PhosphorIcon(
                                PhosphorIcons.checkCircle(
                                  PhosphorIconsStyle.fill,
                                ),
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
