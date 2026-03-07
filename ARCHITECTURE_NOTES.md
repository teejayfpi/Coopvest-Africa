# Architecture Notes: Admin Separation from Mobile App

**Date:** January 2026  
**Purpose:** Document the architectural decision to separate admin functionality from the mobile app

---

## 📋 Executive Summary

This document outlines the architectural decision to remove all admin functionality from the Coopvest Africa mobile app and route all administrative operations to a dedicated web portal.

### Key Changes

| Before | After |
|--------|-------|
| Admin screens in mobile app | Admin web portal (admin.coopvestafrica.org) |
| Mixed user roles | Member-only mobile app |
| Complex permissions | Clear role separation |
| Admin API in mobile backend | Dedicated admin API endpoints |

---

## 🎯 Decision Rationale

### A. Security & Risk Control

Admin actions involve highly sensitive operations:
- **Loan approvals** - Financial decisions affecting capital
- **Interest adjustments** - Rate modifications impacting all members
- **Rollovers** - Loan restructuring decisions
- **Guarantor validation** - Risk assessment
- **Referral abuse reviews** - Fraud prevention

**Mobile App Risks:**
- Increased attack surface on personal devices
- Risk of device compromise (malware, jailbreak)
- Difficult to enforce role-based access control
- No IP-based restrictions possible

**Web Portal Benefits:**
- IP whitelisting capabilities
- Stronger MFA enforcement
- Session control and timeout policies
- Comprehensive audit logging
- Easier compliance with financial regulations

### B. Cleaner UX for Members

Members should never see administrative controls. Removing admin features:

- **Reduces app complexity** - Simpler navigation for members
- **Improves performance** - Fewer screens, smaller APK
- **Prevents accidental exposure** - No risk of members accessing admin controls
- **Better focus** - App designed specifically for member use cases

### C. Faster Development & Maintenance

- **Mobile team** focuses on member experience
- **Admin team** evolves features independently
- **No dual UI logic** - Different platforms, different codebases
- **Easier testing** - Separate test suites for each platform

### D. Compliance & Audit Readiness

Financial cooperatives require strong compliance:

- **Full audit trails** - Every admin action logged
- **Role segmentation** - Reviewer, Approver, Super Admin
- **Exportable reports** - Compliance documentation
- **Regulatory monitoring** - Easier to demonstrate control

---

## 🏗️ Recommended Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Coopvest Africa Platform                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐│
│  │   Mobile App        │    │      Admin Web Portal           ││
│  │   (Member Only)     │    │   admin.coopvestafrica.org      ││
│  │                     │    │                                 ││
│  │  • Registration     │    │  • Loan approval                ││
│  │  • KYC Submission   │    │  • Rollover review              ││
│  │  • Wallet           │    │  • Guarantor validation         ││
│  │  • Loan Application │    │  • Interest adjustments         ││
│  │  • Guarantor Flow   │    │  • Risk management              ││
│  │  • Investments      │    │  • Compliance & audit           ││
│  │  • Support          │    │  • Member management            ││
│  │  • Profile          │    │  • System configuration         ││
│  │  • Notifications    │    │  • Reports & analytics          ││
│  └─────────────────────┘    └─────────────────────────────────┘│
│            │                           │                        │
│            │     ┌─────────────────┐   │                        │
│            └────►│   Shared API    │◄──┘                        │
│                  │   Gateway       │                            │
│                  └────────┬────────┘                           │
│                           │                                     │
│                  ┌────────┴────────┐                           │
│                  │   Shared Backend│                           │
│                  │   (MongoDB)     │                           │
│                  └─────────────────┘                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### A. Mobile App (Flutter – Member Only)

**Includes:**
- Registration & KYC
- Savings & wallet management
- Loan application (submission only)
- Referral dashboard
- Support & AI assistant
- Notifications
- Guarantor flow (scan QR, consent)
- Investment participation

**Excludes:**
- Loan approval
- Interest changes
- Rollover approval
- Guarantor confirmation review
- Fraud decisions
- Member suspension
- System configuration

### B. Admin Website (Web App)

**Accessed via:** `admin.coopvestafrica.org`

**Includes:**
- Loan review & approval
- Guarantor consent validation
- Rollover decisions
- Referral abuse review
- Interest rate management
- Support ticket handling
- System configuration
- Compliance & audit logs

### C. Shared Backend (Single Source of Truth)

- **One database** - MongoDB with proper collections
- **One business logic layer** - Shared models and services
- **Strict role-based API access** - Middleware for permissions
- **API gateway** - Enforcing permissions at the edge

---

## 👥 Role Handling (Clean Model)

| Role | Platform | Access Level |
|------|----------|--------------|
| **Member** | Mobile App | Full member features, no admin |
| **Guarantor** | Mobile App | Scan QR, consent/decline |
| **Support Agent** | Admin Web Portal | View member data, handle tickets |
| **Loan Officer** | Admin Web Portal | Review & approve loans |
| **Risk Officer** | Admin Web Portal | Risk assessment, guarantor validation |
| **Super Admin** | Admin Web Portal | Full system access |

---

## 🔄 How the App "Directs" to the Admin Website

### Implementation: No Admin Login in App

```dart
// In the mobile app, there's NO admin login option
// Admin users access the web portal directly

// When a member needs admin-related info:
class AdminWebLinkScreen extends StatelessWidget {
  const AdminWebLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('Admin access is available on the web portal'),
          ElevatedButton(
            onPressed: () => launchUrl('https://admin.coopvestafrica.org'),
            child: const Text('Open Admin Portal'),
          ),
        ],
      ),
    );
  }
}
```

### Key Points

1. **No admin login in mobile app** - Clear separation
2. **Admins use web portal only** - `admin.coopvestafrica.org`
3. **Shared credentials** - Same login system, different portal
4. **Role-based routing** - App redirects based on user role

---

## 📁 Files Modified

### Removed from Mobile App

| File | Action |
|------|--------|
| `lib/presentation/screens/admin/` | Deleted entire directory |
| `lib/presentation/navigation/rollover_routes.dart` | Removed admin routes |
| `lib/data/api/rollover_api_service.dart` | Removed admin endpoints |
| `lib/data/repositories/rollover_repository.dart` | Removed admin methods |
| `lib/presentation/providers/rollover_provider.dart` | Removed admin state |

### Documentation Updates

| File | Changes |
|------|---------|
| `README.md` | Updated architecture, member-only focus |
| `QUICK_REFERENCE.md` | Updated feature list, role table |
| `ARCHITECTURE_NOTES.md` | **NEW** - This file |

---

## 🔐 Security Implications

### Before (Mobile App Admin)
```
Risk Level: HIGH
- Admin credentials on mobile devices
- No IP restrictions
- Difficult audit trail
- Complex permission checks
```

### After (Web Portal Admin)
```
Risk Level: MEDIUM (Reduced)
- Web-based access control
- IP whitelisting possible
- Full audit logging
- Simpler permission model
```

### Additional Security Measures

1. **MFA Required** - All admin accounts require multi-factor authentication
2. **Session Timeout** - 15-minute timeout for admin sessions
3. **IP Restrictions** - Configurable IP whitelist for admin access
4. **Audit Logging** - Every admin action logged with timestamp, IP, user
5. **Role-Based Access** - Granular permissions (view, edit, approve, delete)

---

## 📊 Compliance Benefits

### Nigerian Financial Regulations

- **NITDA Compliance** - Better data protection controls
- **CBN Guidelines** - Audit trails for financial decisions
- **NDPR** - Personal data protection

### Audit Readiness

- **Exportable reports** - Generate compliance reports on demand
- **User activity logs** - Track all admin actions
- **Decision history** - Audit trail for loan approvals
- **Role changes** - Track permission modifications

---

## 🚀 Deployment Considerations

### Mobile App Deployment

- **Faster releases** - Fewer features, quicker testing
- **Smaller APK** - No admin code included
- **Focused testing** - Member-only functionality

### Admin Portal (Existing)

- **Independent releases** - No mobile app dependencies
- **Full feature set** - Complete administrative capabilities
- **Enterprise-grade** - Built for financial operations

### Backend Changes

- **API Gateway** - Route admin endpoints to web portal
- **Authentication** - Shared auth, different portal access
- **Database** - No schema changes needed
- **Monitoring** - Separate metrics for each portal

---

## 📝 Implementation Checklist

### Mobile App Changes
- [x] Remove admin screens
- [x] Remove admin routes
- [x] Remove admin API endpoints
- [x] Update navigation
- [x] Update documentation

### Admin Portal (Existing)
- [x] Loan approval workflows
- [x] Rollover review system
- [x] Guarantor validation
- [x] Interest management
- [x] Compliance reporting
- [x] Audit logging

### Backend Changes
- [x] API gateway routing
- [x] Role-based access control
- [x] Authentication middleware
- [x] Audit logging

---

## 🔗 Related Documentation

- [Mobile App README](../README.md)
- [Quick Reference](../QUICK_REFERENCE.md)
- [Technical Architecture](../coopvest_technical_architecture.md)
- [Admin Dashboard Repository](https://github.com/coopvestafrica-ops/coopvest_admin_dashboard)

---

## 📅 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | January 2026 | Initial architecture notes |

---

**Maintained by:** Coopvest Africa Development Team  
**Last Updated:** January 2026
