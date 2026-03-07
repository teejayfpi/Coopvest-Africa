# Coopvest Africa Mobile App - User Flows & Information Architecture

**Version:** 1.0  
**Date:** December 2025  
**Platform:** Flutter (iOS & Android)

---

## Table of Contents

1. [Information Architecture](#information-architecture)
2. [Navigation Structure](#navigation-structure)
3. [User Journey Map](#user-journey-map)
4. [Authentication Flow](#authentication-flow)
5. [Onboarding Flow](#onboarding-flow)
6. [Loan Application & Guarantor Flow](#loan-application--guarantor-flow)
7. [Wallet & Contribution Flow](#wallet--contribution-flow)
8. [Investment Participation Flow](#investment-participation-flow)
9. [Error & Exception Flows](#error--exception-flows)
10. [State Management](#state-management)

---

## Information Architecture

### App Structure

```
Coopvest Mobile App
├── Authentication Layer
│   ├── Login
│   ├── Registration
│   ├── KYC Verification
│   ├── Biometric Setup
│   └── Password Recovery
│
├── Main App (Authenticated Users)
│   ├── Home Tab
│   │   ├── Dashboard
│   │   ├── Quick Actions
│   │   ├── Alerts & Notifications
│   │   └── Recent Activity
│   │
│   ├── Wallet Tab
│   │   ├── Wallet Overview
│   │   ├── Contributions
│   │   ├── Transaction History
│   │   ├── Statements
│   │   └── Proof of Contribution
│   │
│   ├── Loans Tab
│   │   ├── Active Loans
│   │   ├── Loan Application
│   │   ├── Get Guarantors (QR)
│   │   ├── Guarantor Requests
│   │   ├── Loan History
│   │   └── Repayment Schedule
│   │
│   ├── Investments Tab
│   │   ├── Investment Pool
│   │   ├── Active Investments
│   │   ├── Project Details
│   │   ├── Performance Tracking
│   │   └── Profit Distribution
│   │
│   ├── Profile Tab
│   │   ├── Profile Information
│   │   ├── KYC Status
│   │   ├── Security Settings
│   │   ├── Biometric Settings
│   │   ├── Device Management
│   │   ├── Notification Preferences
│   │   ├── Help & Support
│   │   ├── About Coopvest
│   │   └── Logout
│   │
│   └── Global Features
│       ├── Scan QR (accessible from any tab)
│       ├── Notifications
│       ├── Search
│       └── Settings
│
└── Offline Mode
    ├── Cached Dashboard
    ├── Cached Transactions
    ├── Cached Loan Status
    └── Sync on Reconnect
```

---

## Navigation Structure

### Bottom Tab Navigation

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│                   [Screen Content]                  │
│                                                     │
├─────────────────────────────────────────────────────┤
│ [Home] [Wallet] [Loans] [Investments] [Profile]    │
│   🏠      💰      📋      📈          👤           │
└─────────────────────────────────────────────────────┘
```

### Tab Specifications

| Tab | Icon | Label | Purpose | Badge |
|-----|------|-------|---------|-------|
| **Home** | 🏠 | Home | Dashboard & overview | Alerts count |
| **Wallet** | 💰 | Wallet | Contributions & balance | Pending count |
| **Loans** | 📋 | Loans | Loan management | Pending count |
| **Investments** | 📈 | Investments | Investment pool | New count |
| **Profile** | 👤 | Profile | Settings & account | None |

### Global Actions

- **Scan QR Button:** Floating action button or top-right icon
  - Accessible from any tab
  - Opens camera for QR scanning
  - Handles guarantor requests and referrals

- **Notifications:** Bell icon in top-right
  - Shows unread count
  - Opens notification center
  - Filters by type (Loans, Investments, System)

---

## User Journey Map

### New Member Journey (First-Time User)

```
START
  ↓
[Welcome Screen] - Explain Coopvest mission
  ↓
[Create Account] - Email/Phone registration
  ↓
[Email Verification] - Confirm email/phone
  ↓
[KYC Submission] - Personal info, ID, selfie
  ↓
[KYC Verification] - Admin review (24-48 hours)
  ↓
[Biometric Setup] - Fingerprint/Face ID
  ↓
[PIN Setup] - Backup authentication
  ↓
[Onboarding Tour] - App features walkthrough
  ↓
[Home Dashboard] - Ready to use app
  ↓
[First Contribution] - Make initial deposit
  ↓
[Loan Application] - Optional: Apply for loan
  ↓
[Active Member] - Full app access
```

### Existing Member Journey (Daily Use)

```
START
  ↓
[Login] - Biometric or PIN
  ↓
[Home Dashboard] - View balance, alerts
  ↓
[Choose Action]
  ├─→ [Make Contribution] → [Confirm] → [Success]
  ├─→ [Apply for Loan] → [Fill Form] → [Get Guarantors]
  ├─→ [Scan Guarantor QR] → [Approve] → [Confirm]
  ├─→ [View Investments] → [Participate] → [Confirm]
  └─→ [Check Profile] → [Update Settings]
  ↓
[Logout or Continue]
```

### Loan Guarantor Journey

```
START (Guarantor receives notification)
  ↓
[Notification] - "John requested you as guarantor"
  ↓
[Open App] - Tap notification or Scan QR
  ↓
[Guarantor Request Screen]
  ├─ Applicant details
  ├─ Loan amount & tenure
  ├─ Guarantor responsibility notice
  └─ Accept/Decline buttons
  ↓
[Accept] → [Confirm with Biometric/PIN]
  ↓
[Digital Commitment Recorded]
  ├─ Timestamp logged
  ├─ Device info logged
  ├─ Session recorded
  └─ Guarantor limit checked
  ↓
[Success Screen] - "You are now a guarantor"
  ↓
[Applicant Notified] - Real-time update
  ↓
[Loan Progresses] - If 3/3 guarantors confirmed
```

---

## Authentication Flow

### Login Flow

```
START
  ↓
[Login Screen]
  ├─ Email/Phone input
  ├─ Password input
  └─ "Forgot Password?" link
  ↓
[Validate Credentials]
  ├─ Check email/phone exists
  ├─ Verify password
  └─ Check account status
  ↓
[Biometric Prompt] (if enabled)
  ├─ Fingerprint/Face ID
  └─ Fallback to PIN
  ↓
[MFA Challenge] (if enabled)
  ├─ SMS code
  ├─ Email code
  └─ Authenticator app
  ↓
[Session Created]
  ├─ Generate JWT token
  ├─ Store securely
  ├─ Bind to device
  └─ Set timeout (30 minutes)
  ↓
[Home Dashboard]
```

### Registration Flow

```
START
  ↓
[Welcome Screen]
  ├─ "Create Account" button
  └─ "Already have account?" link
  ↓
[Email/Phone Entry]
  ├─ Validate format
  ├─ Check if exists
  └─ Send verification code
  ↓
[Verification Code]
  ├─ Enter 6-digit code
  ├─ Resend option (60s cooldown)
  └─ Verify code
  ↓
[Create Password]
  ├─ Password strength indicator
  ├─ Show/hide toggle
  └─ Confirm password
  ↓
[Personal Information]
  ├─ Full name
  ├─ Date of birth
  ├─ Gender
  ├─ Occupation
  └─ Phone number
  ↓
[KYC Submission]
  ├─ ID type selection
  ├─ ID number entry
  ├─ ID photo upload
  ├─ Selfie capture
  └─ Address verification
  ↓
[Review & Confirm]
  ├─ Review all information
  ├─ Accept terms & conditions
  └─ Submit for verification
  ↓
[Verification Pending]
  ├─ Show status screen
  ├─ Estimated time: 24-48 hours
  └─ Email notification when approved
  ↓
[KYC Approved]
  ↓
[Biometric Setup]
  ├─ Fingerprint registration
  ├─ Face ID registration
  └─ Skip option
  ↓
[PIN Setup]
  ├─ Create 4-6 digit PIN
  ├─ Confirm PIN
  └─ Use as backup
  ↓
[Onboarding Tour]
  ├─ Feature walkthrough
  ├─ Quick tips
  └─ Skip option
  ↓
[Home Dashboard]
```

### KYC Verification Flow

```
START (After Registration)
  ↓
[KYC Status Screen]
  ├─ Status: "Pending Verification"
  ├─ Submitted documents
  ├─ Estimated time
  └─ Support contact
  ↓
[Admin Review] (Backend)
  ├─ Verify identity
  ├─ Check for fraud
  ├─ Validate documents
  └─ Approve or Reject
  ↓
[Notification Sent]
  ├─ Push notification
  ├─ Email notification
  └─ In-app alert
  ↓
[If Approved]
  ├─ Status: "Verified"
  ├─ Full app access
  └─ Can make contributions
  ↓
[If Rejected]
  ├─ Status: "Rejected"
  ├─ Reason provided
  ├─ Resubmit option
  └─ Support contact
```

---

## Onboarding Flow

### Welcome Screens (5-7 screens)

**Screen 1: Welcome**
```
┌─────────────────────────────────┐
│                                 │
│      [Coopvest Logo]            │
│                                 │
│   "Welcome to Coopvest Africa"  │
│                                 │
│   "Save. Borrow. Invest.        │
│    Together."                   │
│                                 │
│   [Get Started Button]          │
│   [Already have account?]       │
│                                 │
└─────────────────────────────────┘
```

**Screen 2: Cooperative Values**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Built on Trust"              │
│                                 │
│   [Icon] Peer Accountability    │
│   Members vouch for each other  │
│                                 │
│   [Next] [Skip]                 │
└─────────────────────────────────┘
```

**Screen 3: Savings**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Save Together"               │
│                                 │
│   [Icon] Monthly Contributions  │
│   Build your savings with peers │
│                                 │
│   [Next] [Skip]                 │
└─────────────────────────────────┘
```

**Screen 4: Loans**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Borrow Easily"               │
│                                 │
│   [Icon] Peer-Backed Loans      │
│   Get loans with guarantors     │
│                                 │
│   [Next] [Skip]                 │
└─────────────────────────────────┘
```

**Screen 5: Investments**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Invest Together"             │
│                                 │
│   [Icon] Profit Sharing         │
│   Grow wealth as a community    │
│                                 │
│   [Next] [Skip]                 │
└─────────────────────────────────┘
```

**Screen 6: Security**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Your Security Matters"       │
│                                 │
│   [Icon] Encrypted & Secure     │
│   Your data is protected        │
│                                 │
│   [Next] [Skip]                 │
└─────────────────────────────────┘
```

**Screen 7: Ready to Start**
```
┌─────────────────────────────────┐
│   [Coopvest Logo]               │
│                                 │
│   "Ready to Get Started?"       │
│                                 │
│   [Create Account Button]       │
│   [Already have account?]       │
│                                 │
└─────────────────────────────────┘
```

---

## Loan Application & Guarantor Flow

### Loan Application Flow

```
START (Member in Loans tab)
  ↓
[Loans Dashboard]
  ├─ Active loans
  ├─ Loan history
  └─ [Apply for Loan] button
  ↓
[Loan Application Form]
  ├─ Loan amount (slider or input)
  ├─ Loan tenure (3, 6, 12 months)
  ├─ Purpose (optional)
  └─ [Calculate Preview] button
  ↓
[Loan Preview]
  ├─ Loan amount
  ├─ Interest rate
  ├─ Monthly repayment
  ├─ Total repayment
  ├─ Guarantor requirement (3 needed)
  └─ [Confirm & Submit] button
  ↓
[Loan Submitted]
  ├─ Status: "Pending Guarantors"
  ├─ Loan ID generated
  ├─ QR code generated
  └─ [Get Guarantors] button
  ↓
[Get Guarantors Screen]
  ├─ QR code displayed
  ├─ "Share with guarantors" option
  ├─ Guarantor progress (0/3, 1/3, 2/3, 3/3)
  ├─ List of guarantors (as they accept)
  └─ [Share QR] button
  ↓
[Waiting for Guarantors]
  ├─ Real-time updates
  ├─ Notifications when guarantor accepts
  └─ [Refresh] button
  ↓
[3 Guarantors Confirmed]
  ├─ Status: "Guarantors Confirmed"
  ├─ QR code expires
  ├─ Moves to admin review
  └─ Notification sent
  ↓
[Admin Review]
  ├─ Status: "Under Review"
  ├─ Estimated time: 24-48 hours
  └─ Notification when approved/rejected
  ↓
[Loan Approved]
  ├─ Status: "Approved"
  ├─ [Accept Loan Agreement] button
  ├─ Digital signature required
  └─ Funds disbursed to wallet
  ↓
[Loan Active]
  ├─ Repayment schedule
  ├─ Monthly reminders
  └─ Early repayment option
```

### Guarantor Approval Flow

```
START (Guarantor receives notification)
  ↓
[Notification]
  ├─ "John Doe requested you as guarantor"
  ├─ Loan amount: ₦500,000
  └─ [View] button
  ↓
[Option 1: Tap Notification]
  ├─ Opens guarantor request screen
  └─ Continues below
  ↓
[Option 2: Scan QR]
  ├─ Open app
  ├─ Tap Scan QR
  ├─ Scan applicant's QR code
  └─ Continues below
  ↓
[Guarantor Request Screen]
  ├─ Applicant photo
  ├─ Applicant name
  ├─ Loan amount: ₦500,000
  ├─ Loan tenure: 12 months
  ├─ Monthly repayment: ₦45,000
  ├─ Guarantor responsibility notice:
  │  "By accepting, you agree to cover
  │   this loan if the applicant defaults"
  ├─ Guarantor's current commitments
  ├─ Guarantor limit remaining
  ├─ [Accept] button
  └─ [Decline] button
  ↓
[Accept Guarantor Request]
  ├─ Biometric/PIN confirmation
  ├─ "Confirm with fingerprint"
  └─ [Confirm] button
  ↓
[Digital Commitment Recorded]
  ├─ Timestamp: 2025-12-23 14:30:45
  ├─ Device ID: [device_id]
  ├─ Session ID: [session_id]
  ├─ IP Address: [ip_address]
  ├─ Guarantor limit updated
  └─ Blockchain record (optional)
  ↓
[Success Screen]
  ├─ "You are now a guarantor"
  ├─ Loan details
  ├─ Your commitment
  ├─ [View Loan] button
  └─ [Done] button
  ↓
[Applicant Notified]
  ├─ Real-time update
  ├─ Guarantor progress: 2/3
  ├─ Notification sent
  └─ Applicant sees guarantor name
  ↓
[Decline Guarantor Request]
  ├─ "Are you sure?"
  ├─ Reason (optional)
  ├─ [Confirm Decline] button
  └─ [Cancel] button
  ↓
[Decline Recorded]
  ├─ Applicant notified
  ├─ Guarantor can be asked again later
  └─ No penalty
```

### QR Code Specifications

```
QR Code Data Structure:
{
  "type": "loan_guarantor",
  "loan_id": "LOAN_20251223_001",
  "applicant_id": "MEMBER_12345",
  "applicant_name": "John Doe",
  "loan_amount": 500000,
  "loan_tenure": 12,
  "interest_rate": 10,
  "monthly_repayment": 45000,
  "created_at": "2025-12-23T14:00:00Z",
  "expires_at": "2025-12-30T14:00:00Z",
  "signature": "hash_signature_for_verification"
}

QR Code Display:
┌─────────────────────────────┐
│                             │
│      [QR Code Image]        │
│                             │
│   Loan ID: LOAN_20251223_001│
│   Amount: ₦500,000          │
│   Tenure: 12 months         │
│                             │
│   [Share] [Copy Link]       │
│                             │
└─────────────────────────────┘
```

---

## Wallet & Contribution Flow

### Wallet Overview

```
START (Member in Wallet tab)
  ↓
[Wallet Dashboard]
  ├─ Wallet balance: ₦250,000
  ├─ Total contributions: ₦150,000
  ├─ Pending contributions: ₦0
  ├─ Available for withdrawal: ₦100,000
  ├─ [Make Contribution] button
  ├─ [View Statements] button
  └─ Recent transactions (last 5)
  ↓
[Transaction List]
  ├─ Date, type, amount, status
  ├─ Contribution: +₦10,000 (Completed)
  ├─ Loan repayment: -₦45,000 (Completed)
  ├─ Interest earned: +₦2,500 (Completed)
  └─ [View All] button
```

### Contribution Flow

```
START (Member taps "Make Contribution")
  ↓
[Contribution Amount]
  ├─ Minimum: ₦5,000
  ├─ Maximum: ₦500,000
  ├─ Suggested: ₦10,000 (monthly)
  ├─ Input field or slider
  └─ [Next] button
  ↓
[Contribution Summary]
  ├─ Amount: ₦10,000
  ├─ Date: Today
  ├─ Total after: ₦160,000
  ├─ Wallet balance after: ₦240,000
  └─ [Confirm] button
  ↓
[Payment Method]
  ├─ Bank transfer
  ├─ Mobile money
  ├─ Card payment
  └─ [Select] button
  ↓
[Payment Processing]
  ├─ Loading spinner
  ├─ "Processing your contribution..."
  └─ Timeout: 30 seconds
  ↓
[Payment Confirmation]
  ├─ Status: "Completed"
  ├─ Transaction ID: TXN_20251223_001
  ├─ Amount: ₦10,000
  ├─ Date: 2025-12-23 14:30:45
  ├─ [Download Receipt] button
  └─ [Done] button
  ↓
[Wallet Updated]
  ├─ Balance: ₦260,000
  ├─ Total contributions: ₦160,000
  └─ Notification sent
```

### Statement Generation

```
START (Member taps "View Statements")
  ↓
[Statements Screen]
  ├─ Date range selector
  ├─ Statement type (Contribution, Loan, All)
  ├─ [Generate Statement] button
  └─ Previous statements list
  ↓
[Statement Generated]
  ├─ PDF document
  ├─ Coopvest digital stamp
  ├─ QR code for verification
  ├─ Member details
  ├─ Transaction list
  ├─ Summary totals
  ├─ [Download] button
  ├─ [Share] button
  └─ [Print] button
  ↓
[Download/Share]
  ├─ Save to device
  ├─ Share via email
  ├─ Share via WhatsApp
  └─ Share via other apps
```

---

## Investment Participation Flow

### Investment Pool Overview

```
START (Member in Investments tab)
  ↓
[Investment Dashboard]
  ├─ Total invested: ₦500,000
  ├─ Current value: ₦550,000
  ├─ Profit earned: ₦50,000
  ├─ Active investments: 3
  ├─ [Browse Projects] button
  └─ Active investments list
  ↓
[Active Investments]
  ├─ Project name
  ├─ Amount invested
  ├─ Current value
  ├─ Profit earned
  ├─ Status (Active, Completed)
  └─ [View Details] button
```

### Investment Participation

```
START (Member browses projects)
  ↓
[Investment Projects List]
  ├─ Project name
  ├─ Target amount
  ├─ Current raised
  ├─ Progress bar
  ├─ Expected return
  ├─ Timeline
  └─ [View Details] button
  ↓
[Project Details]
  ├─ Project description
  ├─ Business plan
  ├─ Expected ROI
  ├─ Timeline
  ├─ Risk assessment
  ├─ Team information
  ├─ [Participate] button
  └─ [Share] button
  ↓
[Investment Amount]
  ├─ Minimum: ₦10,000
  ├─ Maximum: ₦500,000
  ├─ Available balance: ₦250,000
  ├─ Input field
  └─ [Next] button
  ↓
[Investment Summary]
  ├─ Project name
  ├─ Amount: ₦50,000
  ├─ Expected return: ₦5,000 (10%)
  ├─ Timeline: 12 months
  ├─ [Confirm] button
  └─ [Cancel] button
  ↓
[Investment Confirmed]
  ├─ Status: "Completed"
  ├─ Investment ID: INV_20251223_001
  ├─ Amount: ₦50,000
  ├─ [View Investment] button
  └─ [Done] button
  ↓
[Investment Active]
  ├─ Track progress
  ├─ View updates
  ├─ Monitor returns
  └─ Receive notifications
```

---

## Error & Exception Flows

### Network Error

```
[Action Attempted]
  ↓
[Network Error Detected]
  ↓
[Error Screen]
  ├─ Icon: ⚠️
  ├─ Title: "No Internet Connection"
  ├─ Message: "Please check your connection and try again"
  ├─ [Retry] button
  ├─ [Offline Mode] button
  └─ [Help] button
  ↓
[Retry]
  ├─ Check connection
  ├─ Retry action
  └─ Continue or show error again
  ↓
[Offline Mode]
  ├─ Show cached data
  ├─ Queue actions for sync
  └─ Notify when online
```

### Authentication Error

```
[Login Attempted]
  ↓
[Invalid Credentials]
  ↓
[Error Screen]
  ├─ Icon: ❌
  ├─ Title: "Login Failed"
  ├─ Message: "Email or password is incorrect"
  ├─ [Try Again] button
  ├─ [Forgot Password?] button
  └─ [Help] button
  ↓
[Try Again]
  ├─ Clear password field
  ├─ Focus on email field
  └─ Allow retry
  ↓
[Forgot Password]
  ├─ Email verification
  ├─ Reset link sent
  └─ Follow reset flow
```

### Transaction Error

```
[Payment Processing]
  ↓
[Payment Failed]
  ↓
[Error Screen]
  ├─ Icon: ❌
  ├─ Title: "Payment Failed"
  ├─ Message: "Your payment could not be processed. Please try again."
  ├─ Error code: ERR_PAYMENT_001
  ├─ [Retry] button
  ├─ [Use Different Method] button
  └─ [Contact Support] button
  ↓
[Retry]
  ├─ Attempt payment again
  ├─ Show loading state
  └─ Confirm or show error
  ↓
[Use Different Method]
  ├─ Return to payment method selection
  ├─ Try alternative payment method
  └─ Continue
```

### Timeout Error

```
[Action Processing]
  ↓
[30 Second Timeout]
  ↓
[Error Screen]
  ├─ Icon: ⏱️
  ├─ Title: "Request Timed Out"
  ├─ Message: "The request took too long. Please try again."
  ├─ [Retry] button
  ├─ [Go Back] button
  └─ [Help] button
  ↓
[Retry]
  ├─ Attempt action again
  ├─ Show loading state
  └─ Confirm or show error
```

---

## State Management

### Global App States

```
enum AppState {
  SPLASH,           // App loading
  UNAUTHENTICATED,  // Not logged in
  AUTHENTICATING,   // Login in progress
  KYC_PENDING,      // Waiting for KYC approval
  KYC_REJECTED,     // KYC rejected
  AUTHENTICATED,    // Logged in
  OFFLINE,          // No internet
  ERROR             // Critical error
}
```

### User States

```
enum UserState {
  NEW,              // Just registered
  KYC_PENDING,      // Waiting for verification
  KYC_APPROVED,     // Verified
  ACTIVE,           // Full access
  SUSPENDED,        // Account suspended
  DELETED           // Account deleted
}
```

### Loan States

```
enum LoanState {
  DRAFT,                    // Not submitted
  PENDING_GUARANTORS,       // Waiting for 3 guarantors
  GUARANTORS_CONFIRMED,     // 3 guarantors approved
  UNDER_REVIEW,             // Admin reviewing
  APPROVED,                 // Approved by admin
  REJECTED,                 // Rejected by admin
  ACTIVE,                   // Funds disbursed
  REPAYING,                 // In repayment
  COMPLETED,                // Fully repaid
  DEFAULTED                 // Payment missed
}
```

### Guarantor States

```
enum GuarantorState {
  PENDING,          // Waiting for response
  ACCEPTED,         // Accepted
  DECLINED,         // Declined
  EXPIRED,          // QR code expired
  RELEASED          // Loan repaid, commitment released
}
```

### Transaction States

```
enum TransactionState {
  PENDING,          // Processing
  COMPLETED,        // Successful
  FAILED,           // Failed
  CANCELLED,        // Cancelled by user
  REFUNDED          // Refunded
}
```

---

## Next Steps

1. **Create Detailed Screen Mockups** - Design all screens with Figma
2. **Implement Navigation** - Set up Flutter routing and navigation
3. **Build Authentication** - Implement login, registration, KYC
4. **Develop State Management** - Use Provider/Riverpod for state
5. **Create API Integration** - Connect to backend services
6. **Implement Offline Mode** - Cache data locally
7. **Add Notifications** - Push and in-app notifications
8. **Security Implementation** - Encryption, biometric, session management
9. **Testing** - Unit, widget, integration tests
10. **Performance Optimization** - Profile and optimize

