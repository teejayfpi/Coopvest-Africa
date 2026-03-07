#!/usr/bin/env python3
import os
import re

def fix_file(filepath, fixes):
    """Apply fixes to a file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        for pattern, replacement in fixes:
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Fixed: {filepath}")
            return True
        return False
    except Exception as e:
        print(f"❌ Error fixing {filepath}: {e}")
        return False

# Fix 1: Add missing imports to kyc_repository.dart
kyc_repo_fixes = [
    (r"import 'kyc_models\.dart';", "import 'kyc_models.dart';\nimport 'package:dio/dio.dart';"),
]

# Fix 2: Fix loan_api_service.dart - remove default baseUrl
loan_api_fixes = [
    (r"factory LoanApiService\(Dio dio, \{String baseUrl = '/api/v1'\}\) = _LoanApiService;",
     "factory LoanApiService(Dio dio) = _LoanApiService;"),
]

# Fix 3: Fix referral_api_service.dart
referral_api_fixes = [
    (r"factory ReferralApiService\(Dio dio, \{String baseUrl = '/api/v1'\}\) =\s+_ReferralApiService;",
     "factory ReferralApiService(Dio dio) = _ReferralApiService;"),
]

# Fix 4: Fix rollover_api_service.dart
rollover_api_fixes = [
    (r"factory RolloverApiService\(Dio dio, \{String baseUrl = '/api/v1'\}\) =\s+_RolloverApiService;",
     "factory RolloverApiService(Dio dio) = _RolloverApiService;"),
]

# Apply fixes
files_to_fix = {
    'lib/data/repositories/kyc_repository.dart': kyc_repo_fixes,
    'lib/data/api/loan_api_service.dart': loan_api_fixes,
    'lib/data/api/referral_api_service.dart': referral_api_fixes,
    'lib/data/api/rollover_api_service.dart': rollover_api_fixes,
}

print("🔧 Applying automated fixes...")
for filepath, fixes in files_to_fix.items():
    full_path = os.path.join('/workspace/Coop', filepath)
    if os.path.exists(full_path):
        fix_file(full_path, fixes)
    else:
        print(f"⚠️  File not found: {filepath}")

print("\n✅ Automated fixes completed!")
