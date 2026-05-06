extension NumberExtensions on num {
  /// Formats number with thousand separators
  String formatNumber() {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final stringValue = toStringAsFixed(0);
    return stringValue.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  /// Formats number as Nigerian Naira currency
  String formatCurrency() {
    return '₦${formatNumber()}';
  }

  /// Formats number with decimal places
  String formatDecimal(int places) {
    return toStringAsFixed(places);
  }

  /// Converts to percentage string
  String toPercentage({int decimals = 0}) {
    return '${toStringAsFixed(decimals)}%';
  }
}
