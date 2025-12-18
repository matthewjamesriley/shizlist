import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/currency.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_notification.dart';

/// Country/Currency selection screen shown during onboarding
class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  Currency _selectedCurrency = Currency.defaultCurrency;
  List<Currency> _filteredCurrencies = Currency.all;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
        _filteredCurrencies = Currency.all.where((currency) {
          return currency.country.toLowerCase().contains(query) ||
              currency.name.toLowerCase().contains(query) ||
              currency.code.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      await _authService.updateUserCurrency(_selectedCurrency.code);
      if (mounted) {
        context.go('/lists');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotification.show(
          context,
          message: 'Failed to save currency: $e',
          icon: PhosphorIcons.warning(),
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  Text(
                    'Select your country',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us show prices in your local currency',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Search field
                  TextField(
                    controller: _searchController,
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Search country or currency...',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: PhosphorIcon(
                          PhosphorIcons.magnifyingGlass(),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    ),
                  ),
                ],
              ),
            ),

            // Currency list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = _filteredCurrencies[index];
                  final isSelected = currency.code == _selectedCurrency.code;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedCurrency = currency);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Flag
                              Text(
                                currency.flag,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),

                              // Country and currency info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currency.country,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currency.name} (${currency.symbol})',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
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
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currency.code,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isSelected
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
                                  PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
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

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton.primary(
                label: 'Continue',
                onPressed: _isLoading ? null : _handleContinue,
                isLoading: _isLoading,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

