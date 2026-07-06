import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/record/ui/home_screen.dart';
import '../../features/transactions/ui/transactions_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../widgets/app_bottom_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final path = state.matchedLocation;

    if (authState is AuthLoading) return null;

    final isAuthenticated = authState is AuthAuthenticated;
    final isAuthRoute = path == '/login' || path == '/register';

    if (!isAuthenticated && !isAuthRoute) return '/login';
    if (isAuthenticated && isAuthRoute) return '/home';
    return null;
  }
}

// ── Bottom navigation shell ─────────────────────────────────────────────────

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).uri.toString();
    final index = switch (location) {
      String l when l.startsWith('/home') => 0,
      String l when l.startsWith('/transactions') => 1,
      String l when l.startsWith('/dashboard') => 2,
      String l when l.startsWith('/settings') => 3,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/transactions');
            case 2:
              context.go('/dashboard');
            case 3:
              context.go('/settings');
          }
        },
        destinations: [
          AppNavDestination(
            icon: Icons.mic_none,
            activeIcon: Icons.mic,
            label: l10n.home,
          ),
          AppNavDestination(
            icon: Icons.list_alt_outlined,
            activeIcon: Icons.list_alt,
            label: l10n.transactions,
          ),
          AppNavDestination(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: l10n.dashboard,
          ),
          AppNavDestination(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
