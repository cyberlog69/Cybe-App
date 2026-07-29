import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../services/password_health_service.dart';

class PasswordHealthScreen extends StatefulWidget {
  const PasswordHealthScreen({super.key});

  @override
  State<PasswordHealthScreen> createState() => _PasswordHealthScreenState();
}

class _PasswordHealthScreenState extends State<PasswordHealthScreen> {
  PasswordHealthReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    final rep = await PasswordHealthService.analyzeHealth();
    if (mounted) {
      setState(() {
        _report = rep;
        _loading = false;
      });
    }
  }

  Color get _scoreColor {
    final score = _report?.overallHealthScore ?? 100;
    return score < 50 ? AppTheme.danger : score < 75 ? AppTheme.warning : AppTheme.safe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Vault Audit'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadHealth();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: _loading || _report == null
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1E1E30)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70, height: 70,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _scoreColor.withValues(alpha: 0.15),
                              border: Border.all(color: _scoreColor, width: 3),
                            ),
                            child: Text('${_report!.overallHealthScore}%', style: TextStyle(color: _scoreColor, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vault Health Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Text(
                                  _report!.overallHealthScore >= 75 ? 'Healthy Vault' : 'Security Risks Found',
                                  style: TextStyle(color: _scoreColor, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text('${_report!.totalEntries} passwords analyzed', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Risk Stats Row
                    Row(
                      children: [
                        Expanded(child: _statBox('Reused', '${_report!.reusedCount}', AppTheme.danger)),
                        const SizedBox(width: 10),
                        Expanded(child: _statBox('Weak', '${_report!.weakCount}', AppTheme.warning)),
                        const SizedBox(width: 10),
                        Expanded(child: _statBox('Stale (>90d)', '${_report!.staleCount}', AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Issues List
                    const Text('Detected Security Vulnerabilities', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),

                    if (_report!.issues.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E1E30))),
                        child: const Column(
                          children: [
                            Icon(Icons.verified_user_rounded, color: AppTheme.safe, size: 48),
                            SizedBox(height: 12),
                            Text('No Password Security Issues Found!', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('All passwords are strong, unique, and up to date.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ..._report!.issues.map((issue) {
                        final isReused = issue.issueType == 'reused';
                        final color = isReused ? AppTheme.danger : issue.issueType == 'weak' ? AppTheme.warning : AppTheme.primary;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(isReused ? Icons.copy : Icons.warning_amber_rounded, color: color, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${issue.entry.site} (${issue.entry.username})', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(issue.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/passwords/edit/${issue.entry.id}'),
                                child: const Text('Fix', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
