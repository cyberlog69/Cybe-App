import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../core/widgets/cybe_widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;
  double _strength = 0;
  int _step = 0; // 0 = welcome, 1 = create password

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) context.go('/dashboard');
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.danger),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: ResponsiveCenter(
              maxWidth: 480,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _step == 0 ? _buildWelcome() : _buildPasswordSetup(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Welcome to', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 16),
          const CybeLogo.hero(
            size: 100,
            title: 'CYBE',
            subtitle: 'SECURITY SUITE',
          ),
          const SizedBox(height: 16),
          const Text(
            'Your all-in-one mobile & desktop security suite.\nPasswords, files, network & more — all protected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('GET STARTED', style: TextStyle(letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSetup() {
    return SingleChildScrollView(
      key: const ValueKey('password'),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _step = 0),
            ),
            const SizedBox(height: 16),
            const Text('Create Master Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'This password protects your entire vault. Choose something strong and memorable.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            const Text('Master Password', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pwCtrl,
              obscureText: _obscure1,
              onChanged: (v) => setState(() => _strength = CryptoUtils.passwordStrength(v)),
              decoration: InputDecoration(
                hintText: 'Enter a strong password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters required';
                return null;
              },
            ),
            const SizedBox(height: 10),
            // Strength indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _strength,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation(
                  _strength < 0.4 ? AppTheme.danger
                    : _strength < 0.7 ? AppTheme.warning
                    : AppTheme.safe,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CryptoUtils.passwordStrengthLabel(_strength),
                  style: TextStyle(
                    fontSize: 12,
                    color: _strength < 0.4 ? AppTheme.danger
                      : _strength < 0.7 ? AppTheme.warning : AppTheme.safe,
                  ),
                ),
                Text('${(_strength * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Confirm Password', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure2,
              decoration: InputDecoration(
                hintText: 'Repeat your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
              validator: (v) {
                if (v != _pwCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you lose your master password, your data cannot be recovered.',
                      style: TextStyle(color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: state is AuthLoading ? null : _submit,
                  child: state is AuthLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('CREATE SECURE VAULT', style: TextStyle(letterSpacing: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(AuthSetupMasterPassword(_pwCtrl.text));
    }
  }
}
