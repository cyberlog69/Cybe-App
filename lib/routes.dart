// Entry point placeholder — real main.dart is in lib/main.dart
// This file ensures Dart recognizes the project structure

// All feature modules are wired through:
// lib/main.dart → MultiBlocProvider → AppRouter
//
// Routes:
//   /setup           → SetupScreen (first launch)
//   /lock            → LockScreen (auth gate)
//   /dashboard       → DashboardScreen (home)
//   /passwords       → PasswordManagerScreen
//   /passwords/add   → AddPasswordScreen
//   /passwords/edit/:id → AddPasswordScreen (edit mode)
//   /wifi            → WifiScannerScreen
//   /vault           → FileVaultScreen
//   /phishing        → PhishingCheckerScreen
//   /vulnerability   → VulnerabilityScanScreen
//   /usb             → UsbMonitorScreen
//   /network         → NetworkDashboardScreen
