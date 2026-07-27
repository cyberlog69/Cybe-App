import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/lock_screen.dart';
import '../../features/auth/screens/setup_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/password_manager/screens/password_manager_screen.dart';
import '../../features/password_manager/screens/add_password_screen.dart';
import '../../features/wifi_scanner/screens/wifi_scanner_screen.dart';
import '../../features/file_vault/screens/file_vault_screen.dart';
import '../../features/phishing_checker/screens/phishing_checker_screen.dart';
import '../../features/vulnerability_scan/screens/vulnerability_scan_screen.dart';
import '../../features/usb_monitor/screens/usb_monitor_screen.dart';
import '../../features/network_dashboard/screens/network_dashboard_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/lock',
    routes: [
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/passwords',
        builder: (context, state) => const PasswordManagerScreen(),
        routes: [
          GoRoute(path: 'add', builder: (context, state) => const AddPasswordScreen()),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) => AddPasswordScreen(editId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(path: '/wifi', builder: (context, state) => const WifiScannerScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const FileVaultScreen()),
      GoRoute(path: '/phishing', builder: (context, state) => const PhishingCheckerScreen()),
      GoRoute(path: '/vulnerability', builder: (context, state) => const VulnerabilityScanScreen()),
      GoRoute(path: '/usb', builder: (context, state) => const UsbMonitorScreen()),
      GoRoute(path: '/network', builder: (context, state) => const NetworkDashboardScreen()),
    ],
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final isSetup = authState is AuthSetupRequired;
      final isLocked = authState is AuthLocked || authState is AuthInitial;
      final isAuth = authState is AuthAuthenticated;
      final path = state.uri.path;

      if (isSetup && path != '/setup') return '/setup';
      if (isLocked && path != '/lock' && path != '/setup') return '/lock';
      if (isAuth && (path == '/lock' || path == '/setup')) return '/dashboard';
      return null;
    },
  );
}
