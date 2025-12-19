import 'package:flutter/services.dart';

/// Utility class for formatting prices
class PriceFormatter {
  /// Format a price string for display
  /// - Removes leading zeros
  /// - Shows 2 decimal places if has decimal, otherwise integer
  /// - Returns empty string if input is empty/invalid
  static String format(String value) {
    if (value.isEmpty) return '';
    
    // Remove any non-numeric characters except decimal
    String cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Handle multiple decimal points - keep only first
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = '${parts[0]}.${parts[1]}';
    }
    
    // Parse to double and back to handle leading zeros
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return '';
    
    // Check if has decimal
    if (cleaned.contains('.')) {
      // Format with 2 decimal places
      return parsed.toStringAsFixed(2);
    } else {
      // No decimal - show as integer
      return parsed.toInt().toString();
    }
  }
  
  /// Format a double price for display
  static String formatDouble(double? price) {
    if (price == null) return '';
    
    // Check if it's a whole number
    if (price == price.toInt()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }
}

/// Input formatter that only allows valid price input
/// - Only digits and single decimal point
/// - Maximum 2 decimal places
/// - No leading zeros (except for 0.xx)
class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Allow empty
    if (text.isEmpty) return newValue;
    
    // Only allow digits and decimal point
    if (!RegExp(r'^[\d.]*$').hasMatch(text)) {
      return oldValue;
    }
    
    // Only allow one decimal point
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }
    
    // Check decimal places - max 2
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length == 2 && parts[1].length > 2) {
        return oldValue;
      }
    }
    
    // Handle leading zeros
    // Allow "0" and "0." but not "00" or "01" etc.
    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      // Remove leading zeros
      final stripped = text.replaceFirst(RegExp(r'^0+'), '');
      if (stripped.isEmpty || stripped.startsWith('.')) {
        return TextEditingValue(
          text: '0${stripped.isEmpty ? '' : stripped}',
          selection: TextSelection.collapsed(
            offset: stripped.isEmpty ? 1 : stripped.length + 1,
          ),
        );
      }
      return TextEditingValue(
        text: stripped,
        selection: TextSelection.collapsed(offset: stripped.length),
      );
    }
    
    return newValue;
  }
}

