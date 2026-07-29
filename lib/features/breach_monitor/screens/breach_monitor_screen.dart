import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../services/breach_service.dart';

class BreachMonitorScreen extends StatefulWidget {
  const BreachMonitorScreen({super.key});

  @override
  State<BreachMonitorScreen> createState() => _BreachMonitorScreenState();
}

class _BreachMonitorScreenState extends State<BreachMonitorScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _checkingEmail = false;
  bool _checkingPassword = false;
  bool _obscurePassword = true;

  BreachCheckResult? _emailResult;
  BreachCheckResult? _passwordResult;

  Future<void> _checkEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _checkingEmail = true;
      _emailResult = null;
    });

    final result = await BreachService.checkEmail(email);

    if (mounted) {
      setState(() {
        _checkingEmail = false;
        _emailResult = result;
      });
    }
  }

  Future<void> _checkPassword() async {
    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty) return;

    setState(() {
      _checkingPassword = true;
      _passwordResult = null;
    });

    final result = await BreachService.checkPassword(pwd);

    if (mounted) {
      setState(() {
        _checkingPassword = false;
        _passwordResult = result;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dark Web Breach Monitor'),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFF7B1FA2)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_update_warning_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('k-Anonymity Dark Web Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Privacy Guaranteed: Plaintext passwords never leave your device.', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Password Breach Check Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E1E30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check Password Leaks (k-Anonymity SHA-1)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Only the first 5 characters of your password\'s SHA-1 hash are queried against 847M+ leaked credentials.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: 'Enter password to test...',
                              prefixIcon: const Icon(Icons.key),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _checkingPassword ? null : _checkPassword,
                          child: _checkingPassword
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background))
                              : const Text('Check'),
                        ),
                      ],
                    ),
                    if (_passwordResult != null) ...[
                      const SizedBox(height: 16),
                      _buildResultCard(_passwordResult!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Email Leak Auditor Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E1E30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check Email Address Exposure', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Search known data breaches for your email domain.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'user@domain.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _checkingEmail ? null : _checkEmail,
                          child: _checkingEmail
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background))
                              : const Text('Scan Email'),
                        ),
                      ],
                    ),
                    if (_emailResult != null) ...[
                      const SizedBox(height: 16),
                      _buildResultCard(_emailResult!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BreachCheckResult res) {
    final color = res.isCompromised ? AppTheme.danger : AppTheme.safe;
    final icon = res.isCompromised ? Icons.warning_amber_rounded : Icons.verified_user_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(res.isCompromised ? 'Compromised!' : 'Clean / Safe', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(res.message, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                if (res.breaches.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...res.breaches.map((b) => Text('• $b', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
