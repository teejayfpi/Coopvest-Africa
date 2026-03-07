# Coopvest Mobile App - State Management Setup with Riverpod

**Date:** December 2025  
**Status:** Complete

---

## Overview

Complete state management architecture using Riverpod for the Coopvest Africa mobile app. This setup provides:

- ✅ Centralized state management
- ✅ Type-safe providers
- ✅ Automatic dependency injection
- ✅ Reactive data flow
- ✅ Easy testing and debugging

---

## Architecture Layers

### 1. **Data Layer** (`lib/data/`)

#### Models (`lib/data/models/`)

**Authentication Models** (`auth_models.dart`)
- `User` - User entity with KYC status
- `AuthResponse` - Login/register response with tokens
- `LoginRequest` - Login request payload
- `RegisterRequest` - Registration request payload
- `KYCSubmission` - KYC submission data
- `AuthState` - Authentication state enum and class

**Wallet Models** (`wallet_models.dart`)
- `Wallet` - Wallet entity with balance and contributions
- `Transaction` - Transaction entity
- `Contribution` - Contribution entity
- `WalletState` - Wallet state enum and class

**Loan Models** (`loan_models.dart`)
- `Loan` - Loan entity with status and guarantor info
- `Guarantor` - Guarantor entity
- `LoanApplication` - Loan application request
- `LoansState` - Loans state enum and class

#### Repositories (`lib/data/repositories/`)

**Auth Repository** (`auth_repository.dart`)
- `login()` - User login
- `register()` - User registration
- `submitKYC()` - KYC submission
- `getKYCStatus()` - Check KYC status
- `refreshToken()` - Token refresh
- `logout()` - User logout
- `getCurrentUser()` - Get current user
- `verifyEmail()` - Email verification
- `requestPasswordReset()` - Password reset request
- `resetPassword()` - Password reset
- `changePassword()` - Change password

**Wallet Repository** (`wallet_provider.dart`)
- `getWallet()` - Get wallet details
- `getTransactions()` - Get transaction history
- `makeContribution()` - Make contribution
- `getContributions()` - Get contributions
- `generateStatement()` - Generate statement
- `getTransactionReceipt()` - Get receipt

**Loan Repository** (`loan_provider.dart`)
- `getLoans()` - Get user loans
- `getLoanDetails()` - Get loan details
- `applyLoan()` - Apply for loan
- `getGuarantors()` - Get guarantors
- `getGuarantorRequests()` - Get guarantor requests
- `approveAsGuarantor()` - Approve as guarantor
- `declineAsGuarantor()` - Decline as guarantor
- `getRepaymentSchedule()` - Get repayment schedule
- `makeRepayment()` - Make repayment
- `generateQRCode()` - Generate QR code

### 2. **Presentation Layer** (`lib/presentation/providers/`)

#### State Notifiers

**Auth Notifier** (`auth_provider.dart`)
- Manages authentication state
- Handles login, register, logout
- Manages KYC submission and status
- Token refresh and validation

**Wallet Notifier** (`wallet_provider.dart`)
- Manages wallet state
- Handles transactions and contributions
- Manages wallet balance updates

**Loan Notifier** (`loan_provider.dart`)
- Manages loan state
- Handles loan applications
- Manages guarantor approvals
- Tracks loan status

#### Providers

**Auth Providers**
```dart
final authProvider                  // Main auth state
final isAuthenticatedProvider        // Is user authenticated
final currentUserProvider            // Current user
final authStatusProvider             // Auth status
final isKycPendingProvider           // Is KYC pending
final isKycRejectedProvider          // Is KYC rejected
final authErrorProvider              // Auth error message
```

**Wallet Providers**
```dart
final walletProvider                 // Main wallet state
final walletBalanceProvider          // Wallet balance
final totalContributionsProvider     // Total contributions
final transactionsProvider           // Transactions list
final walletErrorProvider            // Wallet error message
```

**Loan Providers**
```dart
final loanProvider                   // Main loan state
final activeLoansProvider            // Active loans
final pendingLoansProvider           // Pending loans
final selectedLoanProvider           // Selected loan
final guarantorsProvider             // Guarantors list
final loanErrorProvider              // Loan error message
```

### 3. **Core Layer** (`lib/core/`)

#### Network (`lib/core/network/api_client.dart`)

**API Client**
- HTTP client with Dio
- Request/response interceptors
- Error handling
- Token management
- Logging

**Interceptors**
- `LoggingInterceptor` - Request/response logging
- `AuthInterceptor` - Token injection
- `ErrorInterceptor` - Error handling

---

## Usage Examples

### Authentication

```dart
// Login
ref.read(authProvider.notifier).login(
  email: 'user@example.com',
  password: 'password123',
);

// Register
ref.read(authProvider.notifier).register(
  email: 'user@example.com',
  password: 'password123',
  name: 'John Doe',
  phone: '+2348012345678',
);

// Submit KYC
ref.read(authProvider.notifier).submitKYC(
  submission: KYCSubmission(
    idType: 'national_id',
    idNumber: '12345678901',
    address: '123 Main St',
    city: 'Lagos',
    state: 'Lagos',
    country: 'Nigeria',
  ),
);

// Check KYC status
ref.read(authProvider.notifier).checkKYCStatus();

// Logout
ref.read(authProvider.notifier).logout();

// Watch auth state
final authState = ref.watch(authProvider);
final isAuthenticated = ref.watch(isAuthenticatedProvider);
final currentUser = ref.watch(currentUserProvider);
```

### Wallet

```dart
// Load wallet
ref.read(walletProvider.notifier).loadWallet();

// Load transactions
ref.read(walletProvider.notifier).loadTransactions(
  page: 1,
  pageSize: 20,
  type: 'contribution',
);

// Make contribution
ref.read(walletProvider.notifier).makeContribution(10000);

// Watch wallet state
final walletState = ref.watch(walletProvider);
final balance = ref.watch(walletBalanceProvider);
final transactions = ref.watch(transactionsProvider);
```

### Loans

```dart
// Load loans
ref.read(loanProvider.notifier).loadLoans();

// Load loan details
ref.read(loanProvider.notifier).loadLoanDetails('loan_id');

// Apply for loan
ref.read(loanProvider.notifier).applyLoan(
  amount: 500000,
  tenure: 12,
  purpose: 'Business expansion',
);

// Approve as guarantor
ref.read(loanProvider.notifier).approveAsGuarantor('loan_id');

// Decline as guarantor
ref.read(loanProvider.notifier).declineAsGuarantor('loan_id');

// Watch loan state
final loansState = ref.watch(loanProvider);
final activeLoans = ref.watch(activeLoansProvider);
final selectedLoan = ref.watch(selectedLoanProvider);
```

---

## File Structure

```
lib/
├── core/
│   ├── network/
│   │   └── api_client.dart          # API client with interceptors
│   └── utils/
│       └── utils.dart               # Utilities, validators, formatters
│
├── data/
│   ├── models/
│   │   ├── auth_models.dart         # Auth models and states
│   │   ├── wallet_models.dart       # Wallet models and states
│   │   └── loan_models.dart         # Loan models and states
│   └── repositories/
│       ├── auth_repository.dart     # Auth repository
│       ├── wallet_provider.dart     # Wallet repository (in provider file)
│       └── loan_provider.dart       # Loan repository (in provider file)
│
└── presentation/
    └── providers/
        ├── auth_provider.dart       # Auth notifier and providers
        ├── wallet_provider.dart     # Wallet notifier and providers
        └── loan_provider.dart       # Loan notifier and providers
```

---

## State Flow Diagram

```
User Action
    ↓
Widget calls ref.read(provider.notifier).method()
    ↓
StateNotifier method executes
    ↓
Repository method called
    ↓
API Client makes HTTP request
    ↓
Response received
    ↓
State updated via state = state.copyWith(...)
    ↓
Widgets watching provider rebuild automatically
```

---

## Error Handling

All repositories and notifiers include comprehensive error handling:

```dart
try {
  // Perform action
} catch (e) {
  logger.e('Error: $e');
  state = state.copyWith(
    status: Status.error,
    error: e.toString(),
  );
  rethrow; // Re-throw for caller to handle
}
```

---

## Testing

Providers are easily testable with Riverpod's testing utilities:

```dart
test('Login success', () async {
  final container = ProviderContainer();
  
  await container.read(authProvider.notifier).login(
    email: 'test@example.com',
    password: 'password123',
  );
  
  final authState = container.read(authProvider);
  expect(authState.status, AuthStatus.authenticated);
});
```

---

## Key Features

✅ **Type Safety** - All models are strongly typed  
✅ **Reactive** - Automatic UI updates on state changes  
✅ **Testable** - Easy to mock and test  
✅ **Scalable** - Easy to add new features  
✅ **Error Handling** - Comprehensive error management  
✅ **Logging** - Built-in logging for debugging  
✅ **Performance** - Efficient state updates  
✅ **Offline Support** - Ready for offline-first architecture  

---

## Next Steps

1. **Implement Investment Provider** - Similar to Loan provider
2. **Add Connectivity Provider** - Monitor network status
3. **Add Theme Provider** - Manage light/dark mode
4. **Add Notification Provider** - Handle push notifications
5. **Add Local Storage** - Persist state locally
6. **Add Caching** - Cache API responses
7. **Add Error Recovery** - Retry logic for failed requests
8. **Add Analytics** - Track user actions

---

## Dependencies

- `riverpod: ^2.4.0` - State management
- `flutter_riverpod: ^2.4.0` - Flutter integration
- `dio: ^5.3.0` - HTTP client
- `equatable: ^2.0.0` - Value equality
- `logger: ^2.0.0` - Logging

---

**Status:** ✅ Complete and Ready for Implementation

