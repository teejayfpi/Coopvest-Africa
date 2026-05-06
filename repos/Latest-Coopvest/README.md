# Coopvest Africa Mobile App - Member Only

A secure, scalable mobile application for Coopvest Africa cooperative financial services platform. Built with Flutter for Android and iOS.

> **⚠️ IMPORTANT: Admin functionality has been moved to the dedicated web portal**
> 
> All admin operations (loan approvals, rollover reviews, guarantor validation, interest adjustments) are now handled exclusively in the admin web portal at **admin.coopvestafrica.org**
>
> The mobile app is now **member-only** for better security and cleaner user experience.

## 🎯 Overview

Coopvest Africa is a national cooperative platform focused on savings, loans, investments, and member-based financial services for salaried workers in African markets.

### Key Features (Member Only)

- **Secure Authentication** - Email/phone registration, biometric login, KYC verification
- **Wallet Management** - Track balance, contributions, transactions, and statements
- **Loan Application** - Apply for loans with QR-based three-guarantor model
- **Guarantor System** - Innovative peer-to-peer loan guarantor verification
- **Rollover Requests** - Request loan rollovers (approval handled via admin portal)
- **Investment Pool** - Participate in cooperative investment projects
- **Real-Time Tracking** - WebSocket-based progress updates
- **Offline Support** - Works seamlessly on low-bandwidth networks
- **Dark Mode** - Full light and dark theme support

### What's NOT in the Mobile App

The following admin-only operations have been removed from the mobile app:

- ❌ Loan approval workflows
- ❌ Rollover approval/rejection
- ❌ Guarantor consent review
- ❌ Interest rate adjustments
- ❌ Risk scoring
- ❌ Compliance monitoring
- ❌ Member suspension/activation
- ❌ System configuration

All these operations are handled in the **Admin Web Portal**.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Coopvest Africa Platform                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐│
│  │   Mobile App        │    │      Admin Web Portal           ││
│  │   (Member Only)     │    │   (admin.coopvestafrica.org)    ││
│  │                     │    │                                 ││
│  │  • Registration     │    │  • Loan approval                ││
│  │  • KYC Submission   │    │  • Rollover review              ││
│  │  • Wallet           │    │  • Guarantor validation         ││
│  │  • Loan Application │    │  • Interest adjustments         ││
│  │  • Guarantor Flow   │    │  • Risk management              ││
│  │  • Investments      │    │  • Compliance & audit           ││
│  │  • Support          │    │  • Member management            ││
│  └─────────────────────┘    └─────────────────────────────────┘│
│            │                           │                        │
│            └───────────┬───────────────┘                        │
│                        ▼                                         │
│              ┌─────────────────────┐                            │
│              │   Shared Backend    │                            │
│              │   (Single API)      │                            │
│              └─────────────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Architecture?

1. **Security & Risk Control**
   - Admin actions involve sensitive financial decisions
   - Web portal allows IP restrictions, MFA, session control
   - Reduces attack surface on mobile devices

2. **Cleaner UX for Members**
   - Members never see admin controls
   - Simpler, focused interface
   - Better performance

3. **Compliance & Audit**
   - Full audit trails in admin portal
   - Role segmentation (Reviewer, Approver, Super Admin)
   - Exportable compliance reports

4. **Faster Development**
   - Mobile team focuses on member experience
   - Admin features evolve independently
   - No dual UI logic

## 💻 Technology Stack

### Frontend (Mobile App)
- **Framework:** Flutter 3.16+
- **Language:** Dart 3.2+
- **State Management:** Riverpod 2.4+
- **Architecture:** Clean Architecture with MVVM

### Networking & API
- **HTTP Client:** Dio 5.3+
- **API Integration:** Retrofit 4.0+
- **JSON Serialization:** json_serializable 6.7+

### Storage & Security
- **Local Database:** SQLite 2.3+
- **Secure Storage:** flutter_secure_storage 9.0+
- **Encryption:** encrypt 5.0+
- **Biometric Auth:** local_auth 2.1+

### QR & Scanning
- **QR Generation:** qr_flutter 4.0+
- **QR Scanning:** mobile_scanner 3.5+

### Notifications
- **Push Notifications:** Firebase Cloud Messaging 14.6+
- **Local Notifications:** flutter_local_notifications 16.1+

### UI & Design
- **Design System:** Material Design 3
- **Typography:** Inter font family
- **Icons:** Material Design Icons + Custom

## 📁 Project Structure

```
lib/
├── config/
│   ├── app_config.dart              # App constants
│   └── theme_config.dart            # Design system & themes
├── core/
│   ├── network/
│   │   └── api_client.dart          # API client with interceptors
│   └── utils/
│       └── utils.dart               # Validators, formatters, extensions
├── data/
│   ├── api/
│   │   └── rollover_api_service.dart # Member-only API calls
│   ├── models/
│   │   ├── auth_models.dart         # Authentication models
│   │   ├── wallet_models.dart       # Wallet models
│   │   ├── loan_models.dart         # Loan models
│   │   └── rollover_models.dart     # Rollover models
│   └── repositories/
│       ├── auth_repository.dart     # Authentication repository
│       └── rollover_repository.dart # Member-only rollover operations
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart       # Auth state management
│   │   ├── wallet_provider.dart     # Wallet state management
│   │   ├── loan_provider.dart       # Loan state management
│   │   └── rollover_provider.dart   # Member-only rollover state
│   └── screens/
│       ├── auth/                    # Authentication screens
│       ├── home/                    # Home dashboard
│       ├── kyc/                     # KYC flow
│       ├── loan/                    # Loan application & tracking
│       ├── rollover/                # Rollover request flow
│       ├── wallet/                  # Wallet management
│       ├── investments/             # Investment pools
│       ├── profile/                 # Member profile
│       └── support/                 # Support & tickets
└── main.dart                        # App entry point
```

## 🔐 Security Features

- ✅ AES-256 encryption for sensitive data
- ✅ HTTPS/TLS for all communications
- ✅ SSL certificate pinning
- ✅ Biometric authentication
- ✅ Secure token storage
- ✅ Session timeout (30 minutes)
- ✅ Device binding
- ✅ Jailbreak/root detection

## 🎨 Design System

### Colors
- **Primary:** #1B5E20 (Coopvest Green)
- **Secondary:** #2E7D32
- **Tertiary:** #558B2F
- **Success:** #2E7D32
- **Warning:** #F57C00
- **Error:** #C62828

### Typography
- **Font Family:** Inter
- **Scale:** 11-point scale (Display, Headline, Body, Label)
- **Minimum Size:** 14px for body text

## 📱 User Roles

| Role | Platform | Capabilities |
|------|----------|--------------|
| Member | Mobile App | Register, apply for loans, be guarantor, invest, track savings |
| Guarantor | Mobile App | Accept/reject guarantor requests via QR scan |
| Support Agent | Admin Web Portal | Handle member inquiries |
| Loan Officer | Admin Web Portal | Review and approve loans |
| Risk Officer | Admin Web Portal | Risk assessment, guarantor validation |
| Super Admin | Admin Web Portal | Full system access |

## 🚀 Getting Started

### Prerequisites

- Flutter 3.16+ ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Dart 3.2+
- Android Studio or Xcode
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/coopvestafrica-ops/Coop.git
cd Coop

# Install dependencies
flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Building for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 📚 Documentation

- [Design System](./coopvest_design_system.md)
- [User Flows](./coopvest_user_flows.md)
- [Technical Architecture](./coopvest_technical_architecture.md)
- [QR System](./coopvest_qr_guarantor_system.md)
- [Implementation Guide](./COOPVEST_IMPLEMENTATION_GUIDE.md)
- [State Management](./STATE_MANAGEMENT_SETUP.md)

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📊 Performance Targets

- **App Startup:** < 2 seconds
- **Screen Load:** < 1 second
- **Animation FPS:** 60 FPS
- **Memory Usage:** < 150 MB
- **Battery Usage:** < 5% per hour

## 🤝 Contributing

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit your changes (`git commit -m 'Add amazing feature'`)
3. Push to the branch (`git push origin feature/amazing-feature`)
4. Open a Pull Request

## 📄 License

This project is proprietary and confidential. All rights reserved by Coopvest Africa.

## 📞 Support

For support, email support@coopvest.com or visit our website at https://coopvest.com

---

**Last Updated:** January 2026  
**Status:** Active Development - Member Only  
**Maintainer:** Coopvest Africa Development Team
