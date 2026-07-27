import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../network_dashboard/bloc/network_bloc.dart';
import '../widgets/security_score_widget.dart';
import '../widgets/module_card.dart';
import '../widgets/status_bar_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
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
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
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
    );
  }
}
