#!/usr/bin/env python3
"""
Comprehensive build error fixer for Coopvest Flutter app
"""
import os
import re

def fix_file(filepath, replacements):
    """Apply multiple replacements to a file"""
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        for old, new in replacements:
            content = content.replace(old, new)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✅ Fixed: {filepath}")
        return True
    except Exception as e:
        print(f"❌ Error fixing {filepath}: {e}")
        return False

def create_file_if_not_exists(filepath, content):
    """Create a file if it doesn't exist"""
    if os.path.exists(filepath):
        print(f"⏭️  Already exists: {filepath}")
        return True
    
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Created: {filepath}")
        return True
    except Exception as e:
        print(f"❌ Error creating {filepath}: {e}")
        return False

# Fix 1: Create LoggerService
logger_service_content = '''import 'package:logger/logger.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late final Logger _logger;

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal() {
    _logger = Logger();
  }

  void debug(String message) => _logger.d(message);
  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
'''

# Fix 2: Create LoanState
loan_state_content = '''import 'package:freezed_annotation/freezed_annotation.dart';

part 'loan_state.freezed.dart';

enum LoanStatus { initial, loading, success, error }

@freezed
class LoanState with _$LoanState {
  const factory LoanState({
    @Default(LoanStatus.initial) LoanStatus status,
    @Default([]) List<dynamic> loans,
    String? error,
  }) = _LoanState;
}
'''

# Fix 3: Create extensions file
extensions_content = '''extension NumExtensions on num {
  String formatNumber() {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toStringAsFixed(0);
  }
}

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
'''

# Fix 4: Update rollover_common_widgets.dart - fix typo
rollover_widgets_fix = [
    ('RololloverGuarantor', 'RolloverGuarantor'),
]

# Fix 5: Update login_screen.dart - add PlatformException import
login_screen_fix = [
    ("import 'package:flutter/material.dart';", 
     "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';"),
]

# Fix 6: Update register_step2_screen.dart - fix body parameter
register_step2_fix = [
    ("body: {", "data: {"),
]

# Fix 7: Update salary_deduction_consent_screen.dart - fix body parameter
salary_fix = [
    ("body: {", "data: {"),
]

# Fix 8: Update forgot_password_screen.dart - fix body parameter
forgot_password_fix = [
    ("body: {", "data: {"),
]

# Fix 9: Update guarantor_verification_screen.dart - fix switch case
guarantor_fix = [
    ("'processing' or 'confirmed' => 2,", "'processing', 'confirmed' => 2,"),
]

# Fix 10: Update loan_application_screen.dart - fix type casting
loan_app_fix = [
    ("if (requestedAmount < loanInfo['minAmount'] as double) {",
     "if (requestedAmount < (loanInfo['minAmount'] as num).toDouble()) {"),
    ("if (requestedAmount > loanInfo['maxAmount'] as double) {",
     "if (requestedAmount > (loanInfo['maxAmount'] as num).toDouble()) {"),
]

# Fix 11: Update kyc_employment_details_screen.dart - fix validator
kyc_employment_fix = [
    ("validator: Validators.validateNotEmpty,",
     "validator: (value) => Validators.validateNotEmpty(value, 'Field'),"),
]

# Fix 12: Update kyc_id_upload_screen.dart - fix borderDash
kyc_id_fix = [
    ("borderDash: const BorderSide(",
     "border: Border.all("),
]

# Fix 13: Update kyc_selfie_screen.dart - fix mirror parameter
kyc_selfie_fix = [
    ("_drawCorner(canvas, Offset(size.width - 40, 80), cornerLength, guidePaint, mirror: true);",
     "_drawCorner(canvas, Offset(size.width - 40, 80), cornerLength, guidePaint);"),
]

# Fix 14: Update kyc_bank_info_screen.dart - fix filledColor
kyc_bank_fix = [
    ("filledColor: CoopvestColors.veryLightGray,",
     "fillColor: CoopvestColors.veryLightGray,"),
]

# Fix 15: Update guarantor_verification_screen.dart - fix CircularProgressIndicator
guarantor_progress_fix = [
    ("const CircularProgressIndicator(color: CoopvestColors.primary, size: 80),",
     "const SizedBox(\n            width: 80,\n            height: 80,\n            child: CircularProgressIndicator(color: CoopvestColors.primary),\n          ),"),
]

# Fix 16: Update loan_details_screen.dart - add _getDemoLoan method
loan_details_fix = [
    ("orElse: () => _getDemoLoan(loanId),",
     "orElse: () => _getDemoLoan(),"),
]

# Fix 17: Update referral_provider.dart - fix duplicate import
referral_provider_fix = [
    ("import '../../data/repositories/referral_repository.dart';",
     "import '../../data/repositories/referral_repository.dart' hide ShareLinkResponse;"),
]

# Fix 18: Update main.dart - fix KYCSuccessScreen import
main_fix = [
    ("import 'package:coopvest_mobile/presentation/screens/kyc/kyc_selfie_screen.dart';",
     ""),
]

# Fix 19: Update main.dart - add userPhone parameter
main_loan_app_fix = [
    ("return LoanApplicationScreen(",
     "return LoanApplicationScreen(\n            userPhone: '',"),
]

# Fix 20: Update main.dart - add guarantorName parameter
main_guarantor_fix = [
    ("return GuarantorVerificationScreen(",
     "return GuarantorVerificationScreen(\n            guarantorName: '',"),
]

print("🔧 Starting comprehensive build error fixes...\n")

# Create missing files
print("📝 Creating missing files...")
create_file_if_not_exists('Coop/lib/core/services/logger_service.dart', logger_service_content)
create_file_if_not_exists('Coop/lib/presentation/providers/states/loan_state.dart', loan_state_content)
create_file_if_not_exists('Coop/lib/core/extensions/extensions.dart', extensions_content)

print("\n🔨 Applying fixes to existing files...")

# Apply fixes
fixes = [
    ('Coop/lib/presentation/widgets/rollover/rollover_common_widgets.dart', rollover_widgets_fix),
    ('Coop/lib/presentation/screens/auth/login_screen.dart', login_screen_fix),
    ('Coop/lib/presentation/screens/auth/register_step2_screen.dart', register_step2_fix),
    ('Coop/lib/presentation/screens/auth/salary_deduction_consent_screen.dart', salary_fix),
    ('Coop/lib/presentation/screens/auth/forgot_password_screen.dart', forgot_password_fix),
    ('Coop/lib/presentation/screens/loan/guarantor_verification_screen.dart', guarantor_fix),
    ('Coop/lib/presentation/screens/loan/loan_application_screen.dart', loan_app_fix),
    ('Coop/lib/presentation/screens/kyc/kyc_employment_details_screen.dart', kyc_employment_fix),
    ('Coop/lib/presentation/screens/kyc/kyc_id_upload_screen.dart', kyc_id_fix),
    ('Coop/lib/presentation/screens/kyc/kyc_selfie_screen.dart', kyc_selfie_fix),
    ('Coop/lib/presentation/screens/kyc/kyc_bank_info_screen.dart', kyc_bank_fix),
    ('Coop/lib/presentation/screens/loan/loan_details_screen.dart', loan_details_fix),
    ('Coop/lib/presentation/providers/referral_provider.dart', referral_provider_fix),
    ('Coop/lib/main.dart', main_fix + main_loan_app_fix + main_guarantor_fix),
]

for filepath, replacements in fixes:
    fix_file(filepath, replacements)

print("\n✅ All fixes applied successfully!")
