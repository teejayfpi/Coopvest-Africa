extension StringExtensions on String {
  /// Capitalizes the first letter of the string
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Converts string to title case (each word capitalized)
  String toTitleCase() {
    return split(' ')
        .map((word) => word.capitalize())
        .join(' ');
  }

  /// Removes all whitespace
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Checks if string is a valid email
  bool isValidEmail() {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Checks if string is a valid Nigerian phone number.
  ///
  /// Accepts the forms members actually type: "08031234567" (local),
  /// "2348012345678" (country code), "+2348012345678" and "0803 123 4567"
  /// (spaces). Punctuation is stripped first — the previous implementation only
  /// removed a single leading non-digit, so a spaced number such as
  /// "0803 123 4567" failed despite being valid.
  bool isValidPhone() {
    final digits = replaceAll(RegExp(r'[\s+\-()]'), '');
    return RegExp(r'^\d{11,13}$').hasMatch(digits);
  }
}
