import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../../auth/bloc/auth_bloc.dart';

import '../widgets/security_score_widget.dart';
import '../widgets/module_card.dart';
import '../widgets/status_bar_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = mediaWidth >= 1100 ? 4 : mediaWidth >= 700 ? 3 : 2;
    final childAspectRatio = mediaWidth >= 1100 ? 1.3 : mediaWidth >= 700 ? 1.2 : 1.15;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 1200,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: const Icon(Icons.security, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                        child: const Text('CYBE',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white)),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
                      onPressed: () => context.push('/settings'),
                    ),
                    IconButton(
                      tooltip: 'About Cybe',
                      icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
                      onPressed: () => _showAboutDialog(context),
                    ),
                    IconButton(
                      tooltip: 'Lock App',
                      icon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLockApp());
                        context.go('/lock');
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StatusBarWidget(),
                        const SizedBox(height: 20),
                        const SecurityScoreWidget(),
                        const SizedBox(height: 28),
                        const Text(
                          'Security Modules',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: childAspectRatio,
                          children: const [
                            ModuleCard(
                              title: 'Password Manager',
                              icon: Icons.key_rounded,
                              gradient: AppTheme.primaryGradient,
                              route: '/passwords',
                              subtitle: 'AES-256 encrypted vault',
                            ),
                            ModuleCard(
                              title: 'Wi-Fi Scanner',
                              icon: Icons.wifi_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00796B)]),
                              route: '/wifi',
                              subtitle: 'Network security check',
                            ),
                            ModuleCard(
                              title: 'File Vault',
                              icon: Icons.folder_special_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF4A148C)]),
                              route: '/vault',
                              subtitle: 'Encrypt any file',
                            ),
                            ModuleCard(
                              title: 'Phishing Checker',
                              icon: Icons.phishing_rounded,
                              gradient: LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFBF360C)]),
                              route: '/phishing',
                              subtitle: 'URL threat analysis',
                            ),
                            ModuleCard(
                              title: 'Vulnerability Scan',
                              icon: Icons.bug_report_rounded,
                              gradient: AppTheme.dangerGradient,
                              route: '/vulnerability',
                              subtitle: 'Device risk assessment',
                            ),
                            ModuleCard(
                              title: 'USB Monitor',
                              icon: Icons.usb_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                              route: '/usb',
                              subtitle: 'Port access control',
                            ),
                            ModuleCard(
                              title: 'Network Dashboard',
                              icon: Icons.bar_chart_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF00ACC1), Color(0xFF006064)]),
                              route: '/network',
                              subtitle: 'Live monitoring',
                            ),
                            ModuleCard(
                              title: '2FA Authenticator',
                              icon: Icons.shield_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00838F)]),
                              route: '/totp',
                              subtitle: 'TOTP 2FA tokens',
                            ),
                            ModuleCard(
                              title: 'Secret Notes',
                              icon: Icons.sticky_note_2_rounded,
                              gradient: LinearGradient(colors: [Color(0xFFAB47BC), Color(0xFF4A148C)]),
                              route: '/notes',
                              subtitle: 'AES-256 encrypted notes',
                            ),
                            ModuleCard(
                              title: 'Dark Web Monitor',
                              icon: Icons.security_update_warning_rounded,
                              gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFF880E4F)]),
                              route: '/breach_monitor',
                              subtitle: 'Breach leak lookup',
                            ),
                            ModuleCard(
                              title: 'LAN Port Scanner',
                              icon: Icons.radar_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF00C853), Color(0xFF1B5E20)]),
                              route: '/port_scanner',
                              subtitle: 'Subnet port vulnerability',
                            ),
                            ModuleCard(
                              title: 'SSH & API Keys',
                              icon: Icons.vpn_key_rounded,
                              gradient: LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFFF6D00)]),
                              route: '/ssh_keys',
                              subtitle: 'Developer key vault',
                            ),
                            ModuleCard(
                              title: 'Secure Clipboard',
                              icon: Icons.content_paste_go_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF2979FF)]),
                              route: '/clipboard',
                              subtitle: 'In-app ephemeral buffer',
                            ),
                            ModuleCard(
                              title: 'Security Logs',
                              icon: Icons.list_alt_rounded,
                              gradient: LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFF424242)]),
                              route: '/security_logs',
                              subtitle: 'Audit log & alert stream',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cybe Security', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('v1.0.0 (Build 1)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cybe is an all-in-one mobile security & privacy suite built for Android and iOS.',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text('Security Architecture:', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            _aboutBullet('AES-256-GCM / CBC zero-knowledge local encryption'),
            _aboutBullet('PBKDF2 key derivation (100,000 rounds)'),
            _aboutBullet('Hardware Keystore / Keychain integration'),
            _aboutBullet('Biometric authentication gate & auto-lock'),
            const SizedBox(height: 16),
            const Text('Modules Included:', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            _aboutBullet('Password Manager & Generator'),
            _aboutBullet('Wi-Fi Security & Evil Twin Scanner'),
            _aboutBullet('File Vault & Encrypted Exporter'),
            _aboutBullet('Phishing URL Heuristic Checker'),
            _aboutBullet('Device Vulnerability & Root Auditor'),
            _aboutBullet('USB Access Monitor'),
            _aboutBullet('Network Dashboard & Latency Graph'),
            _aboutBullet('BitMesh — Off-Grid BLE Mesh Messenger'),

          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _aboutBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }
}
