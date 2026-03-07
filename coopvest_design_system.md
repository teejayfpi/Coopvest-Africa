# Coopvest Africa Mobile App - Design System & Architecture

**Version:** 1.0  
**Date:** December 2025  
**Platform:** Flutter (iOS & Android)  
**Target Users:** Cooperative members (salaried workers)

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Component Library](#component-library)
5. [Spacing & Layout](#spacing--layout)
6. [Icons & Imagery](#icons--imagery)
7. [Animations & Transitions](#animations--transitions)
8. [Accessibility Standards](#accessibility-standards)
9. [Dark Mode Implementation](#dark-mode-implementation)
10. [Motion & Micro-interactions](#motion--micro-interactions)

---

## Design Philosophy

### Core Principles

1. **Trust & Transparency**
   - Clear information hierarchy
   - Honest data presentation
   - No hidden fees or surprises
   - Real-time status updates

2. **Cooperative Values**
   - Peer accountability visible
   - Community-focused language
   - Shared responsibility emphasized
   - Member empowerment

3. **Simplicity & Clarity**
   - Minimal financial jargon
   - Clear call-to-action buttons
   - Intuitive navigation
   - Progressive disclosure of information

4. **Accessibility First**
   - Large, readable fonts
   - High contrast ratios
   - Clear icon labels
   - Graceful error handling

5. **Performance Optimized**
   - Fast load times
   - Offline-first approach
   - Optimized for low-end devices
   - Minimal data consumption

---

## Color System

### Primary Colors

| Color | Hex | RGB | Usage | WCAG AA | WCAG AAA |
|-------|-----|-----|-------|---------|---------|
| **Coopvest Primary** | `#1B5E20` | 27, 94, 32 | Primary actions, headers | ✓ | ✓ |
| **Coopvest Secondary** | `#2E7D32` | 46, 125, 50 | Secondary actions, accents | ✓ | ✓ |
| **Coopvest Tertiary** | `#558B2F` | 85, 139, 47 | Tertiary elements | ✓ | ✓ |

### Neutral Colors

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| **Black** | `#000000` | 0, 0, 0 | Text, dark backgrounds |
| **Dark Gray** | `#212121` | 33, 33, 33 | Secondary text |
| **Medium Gray** | `#757575` | 117, 117, 117 | Tertiary text, borders |
| **Light Gray** | `#E0E0E0` | 224, 224, 224 | Dividers, backgrounds |
| **Very Light Gray** | `#F5F5F5` | 245, 245, 245 | Card backgrounds |
| **White** | `#FFFFFF` | 255, 255, 255 | Primary backgrounds |

### Semantic Colors

| Color | Hex | Usage | Light Mode | Dark Mode |
|-------|-----|-------|-----------|-----------|
| **Success** | `#2E7D32` | Positive actions, confirmations | Green-600 | Green-400 |
| **Warning** | `#F57C00` | Alerts, cautions | Orange-700 | Orange-400 |
| **Error** | `#C62828` | Errors, failures | Red-800 | Red-400 |
| **Info** | `#1565C0` | Information, hints | Blue-800 | Blue-400 |

### Color Accessibility

- **Contrast Ratios:**
  - Primary text on white: 7.2:1 (AAA compliant)
  - Secondary text on white: 4.5:1 (AA compliant)
  - All interactive elements: minimum 4.5:1

- **Color Blindness:**
  - Avoid red-green only combinations
  - Use icons + color for status indicators
  - Test with Deuteranopia, Protanopia, Tritanopia

### Light Mode Palette

```
Background: #FFFFFF
Surface: #F5F5F5
Primary: #1B5E20
Secondary: #2E7D32
Text Primary: #212121
Text Secondary: #757575
Divider: #E0E0E0
```

### Dark Mode Palette

```
Background: #121212
Surface: #1E1E1E
Primary: #4CAF50
Secondary: #66BB6A
Text Primary: #FFFFFF
Text Secondary: #B0B0B0
Divider: #424242
```

---

## Typography

### Font Family

- **Primary Font:** Inter (Google Fonts)
  - Clean, modern, highly readable
  - Excellent for African markets
  - Supports multiple languages
  - Free and open-source

- **Fallback:** System fonts (SF Pro Display on iOS, Roboto on Android)

### Type Scale

| Style | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| **Display Large** | 32px | 700 | 40px | -0.5px | Page titles, hero sections |
| **Display Medium** | 28px | 700 | 36px | 0px | Section headers |
| **Display Small** | 24px | 700 | 32px | 0px | Card titles |
| **Headline Large** | 20px | 700 | 28px | 0.15px | Subsection headers |
| **Headline Medium** | 18px | 600 | 26px | 0.15px | Component headers |
| **Headline Small** | 16px | 600 | 24px | 0.15px | Labels, emphasis |
| **Body Large** | 16px | 400 | 24px | 0.5px | Primary body text |
| **Body Medium** | 14px | 400 | 20px | 0.25px | Secondary body text |
| **Body Small** | 12px | 400 | 16px | 0.4px | Tertiary text, captions |
| **Label Large** | 14px | 600 | 20px | 0.1px | Button text, labels |
| **Label Medium** | 12px | 600 | 16px | 0.5px | Small labels |
| **Label Small** | 11px | 600 | 16px | 0.5px | Badges, tags |

### Minimum Font Sizes

- **Body Text:** 14px minimum (16px recommended)
- **Labels:** 12px minimum
- **Captions:** 11px minimum
- **Never below 10px** for any text

### Line Height Guidelines

- **Headings:** 1.2x font size
- **Body Text:** 1.5x font size
- **Labels:** 1.4x font size

---

## Component Library

### Buttons

#### Primary Button
- **Background:** Coopvest Primary (#1B5E20)
- **Text:** White, Label Large (14px, 600)
- **Padding:** 12px horizontal, 16px vertical
- **Border Radius:** 8px
- **States:**
  - Default: Full opacity
  - Hover: 90% opacity
  - Pressed: 80% opacity
  - Disabled: 50% opacity, gray text

#### Secondary Button
- **Background:** Light Gray (#F5F5F5)
- **Text:** Dark Gray (#212121), Label Large
- **Border:** 1px solid Medium Gray (#757575)
- **Padding:** 12px horizontal, 16px vertical
- **Border Radius:** 8px

#### Tertiary Button
- **Background:** Transparent
- **Text:** Coopvest Primary (#1B5E20), Label Large
- **Padding:** 12px horizontal, 16px vertical
- **Border Radius:** 8px

#### Icon Button
- **Size:** 48px × 48px (touch target)
- **Icon Size:** 24px
- **Background:** Transparent or Light Gray on hover
- **Border Radius:** 8px

### Cards

#### Standard Card
- **Background:** White (light mode) / #1E1E1E (dark mode)
- **Border Radius:** 12px
- **Padding:** 16px
- **Shadow:** 0px 2px 4px rgba(0,0,0,0.1)
- **Divider:** Light Gray (#E0E0E0)

#### Elevated Card
- **Shadow:** 0px 4px 8px rgba(0,0,0,0.15)
- **Used for:** Important information, CTAs

#### Outlined Card
- **Border:** 1px solid Light Gray (#E0E0E0)
- **Shadow:** None
- **Used for:** Secondary information

### Input Fields

#### Text Input
- **Height:** 48px (touch target)
- **Padding:** 12px horizontal, 12px vertical
- **Border Radius:** 8px
- **Border:** 1px solid Light Gray (#E0E0E0)
- **Focus State:** 2px solid Coopvest Primary (#1B5E20)
- **Font:** Body Medium (14px)
- **Placeholder:** Medium Gray (#757575)

#### Dropdown
- **Height:** 48px
- **Padding:** 12px horizontal, 12px vertical
- **Border Radius:** 8px
- **Arrow Icon:** 24px, Coopvest Primary

#### Checkbox
- **Size:** 24px × 24px
- **Border Radius:** 4px
- **Checked:** Coopvest Primary background, white checkmark
- **Unchecked:** Light Gray border

#### Radio Button
- **Size:** 24px × 24px
- **Outer Circle:** Light Gray border
- **Inner Circle (checked):** Coopvest Primary, 8px diameter

### Modals & Dialogs

#### Modal
- **Background Overlay:** Black with 40% opacity
- **Modal Background:** White (light) / #1E1E1E (dark)
- **Border Radius:** 16px (top corners)
- **Padding:** 24px
- **Max Width:** 90% of screen width
- **Animation:** Slide up from bottom (300ms)

#### Alert Dialog
- **Title:** Display Small (24px, 700)
- **Message:** Body Medium (14px, 400)
- **Buttons:** Primary + Secondary buttons
- **Spacing:** 16px between elements

### Chips & Tags

#### Chip
- **Height:** 32px
- **Padding:** 8px horizontal, 6px vertical
- **Border Radius:** 16px
- **Background:** Light Gray (#F5F5F5)
- **Text:** Label Medium (12px, 600)
- **Icon:** 16px, optional

#### Status Badge
- **Height:** 24px
- **Padding:** 4px horizontal, 2px vertical
- **Border Radius:** 12px
- **Font:** Label Small (11px, 600)
- **Colors:** Success (green), Warning (orange), Error (red), Info (blue)

### Navigation

#### Bottom Navigation Bar
- **Height:** 64px (including safe area)
- **Background:** White (light) / #1E1E1E (dark)
- **Border Top:** 1px solid Light Gray (#E0E0E0)
- **Items:** 5 tabs maximum
- **Icon Size:** 24px
- **Label:** Label Small (11px, 600)
- **Active Color:** Coopvest Primary (#1B5E20)
- **Inactive Color:** Medium Gray (#757575)

#### Top App Bar
- **Height:** 56px
- **Background:** White (light) / #1E1E1E (dark)
- **Title:** Headline Large (20px, 700)
- **Padding:** 16px horizontal, 8px vertical
- **Shadow:** 0px 2px 4px rgba(0,0,0,0.1)

### Progress Indicators

#### Linear Progress Bar
- **Height:** 4px
- **Background:** Light Gray (#E0E0E0)
- **Progress:** Coopvest Primary (#1B5E20)
- **Border Radius:** 2px

#### Circular Progress
- **Size:** 48px
- **Stroke Width:** 4px
- **Color:** Coopvest Primary (#1B5E20)

#### Step Indicator
- **Circle Size:** 32px
- **Active:** Coopvest Primary background, white text
- **Completed:** Coopvest Primary background, checkmark
- **Inactive:** Light Gray background, gray text
- **Connector Line:** 2px, Light Gray

---

## Spacing & Layout

### Spacing Scale

```
xs: 4px
sm: 8px
md: 12px
lg: 16px
xl: 24px
xxl: 32px
xxxl: 48px
```

### Grid System

- **Base Unit:** 4px
- **Column Grid:** 4 columns (mobile), 8 columns (tablet)
- **Gutter:** 16px (mobile), 24px (tablet)
- **Margin:** 16px (mobile), 24px (tablet)

### Safe Areas

- **Top Safe Area:** 44px (iOS), 24px (Android)
- **Bottom Safe Area:** 34px (iPhone X+), 0px (standard)
- **Horizontal Safe Area:** 16px minimum

### Card Spacing

- **Between Cards:** 12px
- **Card Padding:** 16px
- **Content Padding:** 12px

### Section Spacing

- **Between Sections:** 24px
- **Section Header to Content:** 12px
- **Content to Next Section:** 24px

---

## Icons & Imagery

### Icon System

- **Icon Library:** Material Design Icons + Custom Coopvest Icons
- **Sizes:** 16px, 20px, 24px, 32px, 48px
- **Stroke Width:** 2px (consistent)
- **Color:** Inherit from text color or semantic color

### Icon Categories

1. **Navigation Icons**
   - Home, Wallet, Loans, Investments, Profile
   - Menu, Back, Close, Search

2. **Action Icons**
   - Add, Edit, Delete, Share, Download
   - Send, Receive, Scan, Camera

3. **Status Icons**
   - Check, Close, Warning, Info, Error
   - Pending, Approved, Rejected

4. **Financial Icons**
   - Money, Wallet, Bank, Card, Transaction
   - Loan, Investment, Savings, Interest

5. **Social Icons**
   - User, Users, Share, Comment, Like
   - Notification, Bell, Message

### Image Guidelines

- **Aspect Ratios:** 16:9 (hero), 1:1 (avatars), 4:3 (cards)
- **Compression:** Optimize for mobile (max 200KB per image)
- **Formats:** WebP (primary), PNG (fallback)
- **Resolution:** 2x density for retina displays

### Avatar System

- **Sizes:** 32px, 48px, 64px, 96px
- **Border Radius:** 50% (circular)
- **Fallback:** User initials on colored background
- **Colors:** Rotate through Coopvest color palette

---

## Animations & Transitions

### Duration Standards

| Type | Duration | Easing |
|------|----------|--------|
| **Micro-interactions** | 150ms | Ease-out |
| **Standard transitions** | 300ms | Ease-in-out |
| **Page transitions** | 400ms | Ease-out |
| **Loading animations** | 1000ms+ | Linear |

### Easing Functions

```
Ease-out: cubic-bezier(0.0, 0.0, 0.2, 1.0)
Ease-in-out: cubic-bezier(0.4, 0.0, 0.2, 1.0)
Ease-in: cubic-bezier(0.4, 0.0, 1.0, 1.0)
Linear: cubic-bezier(0.0, 0.0, 1.0, 1.0)
```

### Common Animations

1. **Button Press**
   - Scale: 0.98x
   - Duration: 150ms
   - Easing: Ease-out

2. **Card Entrance**
   - Fade in + Slide up
   - Duration: 300ms
   - Easing: Ease-out

3. **Modal Appearance**
   - Slide up from bottom
   - Duration: 300ms
   - Easing: Ease-out

4. **Loading Spinner**
   - Continuous rotation
   - Duration: 1000ms
   - Easing: Linear

5. **Success Checkmark**
   - Scale + Fade in
   - Duration: 400ms
   - Easing: Ease-out

---

## Accessibility Standards

### WCAG 2.1 Level AA Compliance

- **Color Contrast:** Minimum 4.5:1 for text
- **Touch Targets:** Minimum 48px × 48px
- **Focus Indicators:** Visible 2px outline
- **Motion:** Respect `prefers-reduced-motion`
- **Text Alternatives:** All images have alt text

### Keyboard Navigation

- **Tab Order:** Logical, left-to-right, top-to-bottom
- **Focus Visible:** Clear 2px outline in Coopvest Primary
- **Escape Key:** Closes modals and menus
- **Enter Key:** Activates buttons and links

### Screen Reader Support

- **Semantic HTML:** Proper heading hierarchy
- **ARIA Labels:** For icon-only buttons
- **Live Regions:** For dynamic content updates
- **Form Labels:** Associated with inputs

### Text Accessibility

- **Font Size:** Minimum 14px for body text
- **Line Height:** 1.5x for body text
- **Letter Spacing:** 0.5px for body text
- **Avoid All Caps:** Use title case instead

### Motion & Animation

- **Respect Preferences:** Check `prefers-reduced-motion`
- **No Auto-play:** Videos and animations don't auto-play
- **Pause Controls:** Animations can be paused
- **No Flashing:** Avoid content flashing more than 3x per second

---

## Dark Mode Implementation

### Automatic Switching

- **System Setting:** Respect device dark mode preference
- **Manual Override:** Allow user to toggle in settings
- **Persistence:** Save user preference locally

### Dark Mode Colors

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Background | #FFFFFF | #121212 |
| Surface | #F5F5F5 | #1E1E1E |
| Primary Text | #212121 | #FFFFFF |
| Secondary Text | #757575 | #B0B0B0 |
| Divider | #E0E0E0 | #424242 |
| Primary Button | #1B5E20 | #4CAF50 |
| Secondary Button | #F5F5F5 | #2C2C2C |

### Dark Mode Adjustments

- **Reduce Brightness:** Avoid pure white (#FFFFFF)
- **Increase Contrast:** Use lighter text on dark backgrounds
- **Soften Shadows:** Reduce shadow opacity in dark mode
- **Adjust Images:** Slightly brighten images in dark mode

---

## Motion & Micro-interactions

### Button Interactions

```
Default State:
  - Opacity: 100%
  - Scale: 1.0x

Hover State:
  - Opacity: 90%
  - Scale: 1.0x

Pressed State:
  - Opacity: 80%
  - Scale: 0.98x
  - Duration: 150ms

Disabled State:
  - Opacity: 50%
  - Scale: 1.0x
```

### Loading States

```
Spinner Animation:
  - Rotation: 360° continuous
  - Duration: 1000ms
  - Easing: Linear
  - Color: Coopvest Primary

Skeleton Loading:
  - Pulse opacity: 0.5 → 1.0 → 0.5
  - Duration: 1500ms
  - Easing: Ease-in-out
```

### Success Feedback

```
Checkmark Animation:
  - Scale: 0 → 1.2 → 1.0
  - Opacity: 0 → 1.0
  - Duration: 400ms
  - Easing: Ease-out
  - Color: Success Green (#2E7D32)
```

### Error Feedback

```
Shake Animation:
  - Translate X: -4px → 4px → -4px → 0px
  - Duration: 300ms
  - Easing: Ease-in-out
  - Color: Error Red (#C62828)
```

---

## Implementation Checklist

- [ ] Color palette defined and tested for accessibility
- [ ] Typography scale implemented in Flutter
- [ ] Component library created with all states
- [ ] Spacing system applied consistently
- [ ] Icon library integrated
- [ ] Animations implemented with proper durations
- [ ] Dark mode fully functional
- [ ] Accessibility audit completed
- [ ] Performance tested on low-end devices
- [ ] Tested with screen readers
- [ ] Keyboard navigation verified
- [ ] Color contrast verified with tools
- [ ] Motion preferences respected
- [ ] Offline states designed
- [ ] Error states designed

---

## Next Steps

1. **Create Flutter Theme Configuration** - Implement all colors, typography, and component styles
2. **Build Component Library** - Create reusable widgets for all components
3. **Design Screen Mockups** - Create detailed designs for all screens
4. **Implement Navigation** - Set up bottom tab navigation and routing
5. **Build Authentication Flow** - Implement login, registration, and KYC
6. **Develop Loan System** - Implement QR-based guarantor flow
7. **Create Wallet System** - Implement transactions and balance management
8. **Add Notifications** - Implement push and in-app notifications
9. **Optimize Performance** - Test on low-end devices and optimize
10. **Security Audit** - Conduct comprehensive security review

