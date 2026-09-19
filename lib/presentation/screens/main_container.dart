import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme_config.dart';
import '../../config/theme_extension.dart';
import '../providers/auth_provider.dart';
import 'home/home_dashboard_screen.dart';
import 'wallet/wallet_dashboard_screen.dart';
import 'loan/loan_dashboard_screen.dart';
import 'profile/profile_settings_screen.dart';

class MainContainer extends ConsumerStatefulWidget {
  const MainContainer({super.key});

  @override
  ConsumerState<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends ConsumerState<MainContainer> {
  int _selectedIndex = 0;

  // Screens are built lazily inside IndexedStack — declaring them here avoids
  // rebuilding the list on every frame while still reacting to user changes.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Screens that need user data read from providers internally.
    // Screens that accept constructor params (userId, etc.) get them from
    // the provider inside the screen itself to avoid rebuild on every frame.
    _screens = const [
      HomeDashboardScreen(),
      _WalletTab(),
      _LoanTab(),
      ProfileSettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          // Flat: a single hairline top border instead of a drop shadow.
          border: Border(top: BorderSide(color: CoopvestColors.cardBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: CoopvestColors.white,
          selectedItemColor: CoopvestColors.primary,
          // Inactive label sits at the hint token, which is AA-compliant on
          // white (the old secondary grey was borderline at this size).
          unselectedItemColor: CoopvestColors.textHint,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
          // The active tab gets a soft emerald pill behind the icon, so the
          // state does not rely on colour alone — the pill and the filled icon
          // are both shape cues.
          items: const [
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.home_outlined),
              activeIcon: _NavIcon(icon: Icons.home, active: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.account_balance_wallet_outlined),
              activeIcon:
                  _NavIcon(icon: Icons.account_balance_wallet, active: true),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.description_outlined),
              activeIcon: _NavIcon(icon: Icons.description, active: true),
              label: 'Loans',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.person_outline),
              activeIcon: _NavIcon(icon: Icons.person, active: true),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widgets that read user data from providers internally,
/// preventing MainContainer from rebuilding the full screens list on
/// every provider change.
class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return WalletDashboardScreen(
      userId: user?.id ?? '',
      userName: user?.name ?? 'User',
    );
  }
}

class _LoanTab extends ConsumerWidget {
  const _LoanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return LoanDashboardScreen(
      userId: user?.id ?? '',
      userName: user?.name ?? 'User',
      userPhone: user?.phone ?? '',
    );
  }
}

/// Bottom-nav icon with an optional soft emerald pill behind it.
///
/// The pill is generated natively by [BottomNavigationBar] unless a custom
/// icon is supplied; supplying one keeps the size and radius consistent with
/// the rest of the app (10px chip radius) instead of the Material default.
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _NavIcon({required this.icon, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: active
          ? BoxDecoration(
              color: CoopvestColors.iconTintGreen,
              borderRadius: BorderRadius.circular(CoopvestShape.chipRadius + 6),
            )
          : null,
      child: Icon(icon, size: 22),
    );
  }
}
