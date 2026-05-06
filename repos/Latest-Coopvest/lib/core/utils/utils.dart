import 'package:logger/logger.dart';

/// Global logger instance
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Custom exceptions
abstract class AppException implements Exception {
  final String message;
  AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class AuthException extends AppException {
  AuthException(String message) : super(message);
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message);
}

class ServerException extends AppException {
  final int? statusCode;
  ServerException(String message, {this.statusCode}) : super(message);
}

class CacheException extends AppException {
  CacheException(String message) : super(message);
}

class BiometricException extends AppException {
  BiometricException(String message) : super(message);
}

class SessionExpiredException extends AppException {
  SessionExpiredException() : super('Session expired. Please login again.');
}

class TokenRefreshException extends AppException {
  TokenRefreshException(String message) : super(message);
}

class QRException extends AppException {
  QRException(String message) : super(message);
}

class GuarantorException extends AppException {
  GuarantorException(String message) : super(message);
}

/// Validators
class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^(\+234|0)[0-9]{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid Nigerian phone number';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain a number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain a special character';
    }
    return null;
  }

  static String? validatePIN(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length != 4) {
      return 'PIN must be 4 digits';
    }
    if (!RegExp(r'^[0-9]{4}$').hasMatch(value)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.length > 100) {
      return 'Name must not exceed 100 characters';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}

/// Formatters
class Formatters {
  static String formatCurrency(double amount) {
    return '₦${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  static String formatPhone(String phone) {
    // Format: +234 801 234 5678
    if (phone.startsWith('0')) {
      phone = '+234${phone.substring(1)}';
    }
    if (phone.length == 13) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7, 10)} ${phone.substring(10)}';
    }
    return phone;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatDateTime(DateTime dateTime) {
    final date = formatDate(dateTime);
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  static String formatLoanAmount(double amount) {
    return formatCurrency(amount);
  }

  static String formatMonthlyRepayment(double amount) {
    return formatCurrency(amount);
  }

  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(2)}%';
  }

  static String formatAccountNumber(String accountNumber) {
    // Format: 1234 5678 9012 3456
    if (accountNumber.length == 16) {
      return '${accountNumber.substring(0, 4)} ${accountNumber.substring(4, 8)} ${accountNumber.substring(8, 12)} ${accountNumber.substring(12)}';
    }
    return accountNumber;
  }
}

/// String extensions
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String toTitleCase() {
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  bool isValidEmail() {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  bool isValidPhone() {
    final phoneRegex = RegExp(r'^(\+234|0)[0-9]{10}$');
    return phoneRegex.hasMatch(this);
  }

  bool isValidPassword() {
    return length >= 8 &&
        contains(RegExp(r'[A-Z]')) &&
        contains(RegExp(r'[0-9]')) &&
        contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }
}

/// Number extensions
extension DoubleExtension on double {
  String toCurrency() {
    return Formatters.formatCurrency(this);
  }

  String toPercentage() {
    return Formatters.formatPercentage(this);
  }
}

/// Number extensions
extension NumExtension on num {
  String formatNumber() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// DateTime extensions
extension DateTimeExtension on DateTime {
  String toFormattedDate() {
    return Formatters.formatDate(this);
  }

  String toFormattedDateTime() {
    return Formatters.formatDateTime(this);
  }

  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return toFormattedDate();
    }
  }
}
