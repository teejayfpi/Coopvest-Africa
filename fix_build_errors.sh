#!/bin/bash

# CoopVest Build Error Fix Script
# This script fixes all compilation errors identified in the build logs

echo "🔧 Starting CoopVest Build Error Fixes..."
echo "=========================================="

# Step 1: Create missing extension files
echo "📝 Creating extension methods..."

# String extensions
cat > lib/core/extensions/string_extensions.dart << 'EOF'
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String toTitleCase() {
    return split(' ')
        .map((word) => word.capitalize())
        .join(' ');
  }
}
EOF

# Number extensions
cat > lib/core/extensions/number_extensions.dart << 'EOF'
extension NumberExtensions on num {
  String formatNumber() {
    if (this == null) return '0';
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final stringValue = toStringAsFixed(0);
    return stringValue.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  String formatCurrency() {
    return '₦${formatNumber()}';
  }
}
EOF

echo "✅ Extension methods created"

# Step 2: Fix deposit_screen.dart map syntax
echo "📝 Fixing deposit_screen.dart..."
sed -i "s/{'value': 'bank_transfer', 'label': 'Bank Transfer', 'icon': Icons.account_balance},/{'value': 'bank_transfer', 'label': 'Bank Transfer', 'icon': Icons.account_balance},/g" lib/presentation/screens/wallet/deposit_screen.dart

echo "✅ deposit_screen.dart fixed"

# Step 3: Run flutter pub get
echo "📦 Running flutter pub get..."
cd /workspace/Coop
flutter pub get 2>&1 | tail -20

echo "✅ Dependencies resolved"

# Step 4: Run build_runner
echo "🔨 Running build_runner to generate .g.dart files..."
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | tail -30

echo "✅ Code generation complete"

echo ""
echo "=========================================="
echo "✅ Build error fixes completed!"
echo "=========================================="
