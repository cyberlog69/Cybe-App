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
import '../../features/ble_mesh/screens/ble_mesh_screen.dart';
import '../../features/totp/screens/totp_screen.dart';
import '../../features/breach_monitor/screens/breach_monitor_screen.dart';
import '../../features/secret_notes/screens/secret_notes_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/password_manager/screens/password_health_screen.dart';
import '../../features/port_scanner/screens/port_scanner_screen.dart';
import '../../features/ssh_keys/screens/ssh_keys_screen.dart';
import '../../features/clipboard_manager/screens/clipboard_screen.dart';
import '../../features/security_logs/screens/security_logs_screen.dart';
import '../../features/app_audit/screens/app_audit_screen.dart';
import '../../features/wifi_scanner/screens/mitm_shield_screen.dart';

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
      GoRoute(path: '/blemesh', builder: (context, state) => const BleMeshScreen()),
      GoRoute(path: '/totp', builder: (context, state) => const TotpScreen()),
      GoRoute(path: '/breach_monitor', builder: (context, state) => const BreachMonitorScreen()),
      GoRoute(path: '/notes', builder: (context, state) => const SecretNotesScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/password_health', builder: (context, state) => const PasswordHealthScreen()),
      GoRoute(path: '/port_scanner', builder: (context, state) => const PortScannerScreen()),
      GoRoute(path: '/ssh_keys', builder: (context, state) => const SshKeysScreen()),
      GoRoute(path: '/clipboard', builder: (context, state) => const ClipboardScreen()),
      GoRoute(path: '/security_logs', builder: (context, state) => const SecurityLogsScreen()),
      GoRoute(path: '/app_audit', builder: (context, state) => const AppAuditScreen()),
      GoRoute(path: '/mitm_shield', builder: (context, state) => const MitmShieldScreen()),
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
