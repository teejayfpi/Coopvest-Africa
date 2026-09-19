extension NumberExtensions on num {
  /// Formats number with thousand separators
  String formatNumber() {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final stringValue = toInt().toString();
    return stringValue.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  /// Formats number as Nigerian Naira currency
  String formatCurrency() {
    return '₦${formatNumber()}';
  }

  /// Compact currency for headline figures: ₦1.2M, ₦850K, ₦12,500.
  ///
  /// The dashboard balance can run to millions; at 32px a full "₦1,250,000"
  /// overflows the card on a narrow phone, so large values are abbreviated to
  /// fit on one line. Below 100,000 the exact figure is short enough to keep,
  /// which is where members need precision most (fees, fines, repayments).
  String formatCurrencyCompact() {
    final value = toDouble();
    final abs = value.abs();
    if (abs >= 1000000) {
      final millions = value / 1000000;
      // One decimal, but drop a trailing ".0" so it reads ₦2M not ₦2.0M.
      final text = millions.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return '₦${text}M';
    }
    if (abs >= 100000) {
      final thousands = value / 1000;
      final text = thousands.toStringAsFixed(0);
      return '₦${text}K';
    }
    return '₦⁠${formatNumber()}';
  }

  /// The obscured placeholder shown when the balance is hidden — six dots, as
  /// specified, rather than a string of zeros that reads like a real ₦0.
  static const String hiddenAmount = '••••••';

  /// Formats number with decimal places
  String formatDecimal(int places) {
    return toStringAsFixed(places);
  }

  /// Converts to percentage string
  String toPercentage({int decimals = 0}) {
    return '${(this * 100).toStringAsFixed(decimals)}%';
  }
}
