/// Currency model with code, symbol, and country information
class Currency {
  final String code;
  final String symbol;
  final String name;
  final String country;
  final String flag;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.country,
    required this.flag,
  });

  /// All supported currencies
  static const List<Currency> all = [
    Currency(code: 'GBP', symbol: '£', name: 'British Pound', country: 'United Kingdom', flag: '🇬🇧'),
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar', country: 'United States', flag: '🇺🇸'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro', country: 'European Union', flag: '🇪🇺'),
    Currency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', country: 'Canada', flag: '🇨🇦'),
    Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', country: 'Australia', flag: '🇦🇺'),
    Currency(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', country: 'New Zealand', flag: '🇳🇿'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', country: 'Japan', flag: '🇯🇵'),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', country: 'China', flag: '🇨🇳'),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee', country: 'India', flag: '🇮🇳'),
    Currency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', country: 'Switzerland', flag: '🇨🇭'),
    Currency(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', country: 'Sweden', flag: '🇸🇪'),
    Currency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', country: 'Singapore', flag: '🇸🇬'),
    Currency(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', country: 'Mexico', flag: '🇲🇽'),
    Currency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', country: 'Brazil', flag: '🇧🇷'),
  ];

  /// Default currency (GBP)
  static const Currency defaultCurrency = Currency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    country: 'United Kingdom',
    flag: '🇬🇧',
  );

  /// Get currency by code
  static Currency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => defaultCurrency,
    );
  }

  /// Format a price with this currency's symbol
  String format(double amount) {
    // Handle currencies that typically don't show decimals
    if (code == 'JPY') {
      return '$symbol${amount.round()}';
    }
    // Don't show .00 for whole numbers
    if (amount == amount.roundToDouble() && amount % 1 == 0) {
      return '$symbol${amount.toInt()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Currency && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$flag $code - $name';
}




