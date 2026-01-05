import '../constants/app_constants.dart';

/// Price formatting utilities
class PriceFormatter {
  PriceFormatter._();

  /// Format a price with currency symbol
  static String format(double amount, {String symbol = '£'}) {
    // Don't show decimals for whole numbers
    if (amount == amount.roundToDouble() && amount % 1 == 0) {
      return '$symbol${amount.toInt()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Parse a price string to double
  static double? parse(String value) {
    // Remove currency symbols and whitespace
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }
}




