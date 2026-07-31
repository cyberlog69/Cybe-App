import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/backup_dialogs.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/services/duress_wipe_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Section 1: Appearance & Theme
                  _sectionHeader('Appearance & Interface'),
                  _buildCard([
                    ListTile(
                      leading: const Icon(Icons.palette_outlined, color: AppTheme.primary),
                      title: const Text('Theme Mode', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text('Current: ${state.themeModeString.toUpperCase()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: DropdownButton<String>(
                        value: state.themeModeString,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System Default')),
                          DropdownMenuItem(value: 'dark', child: Text('Cyberpunk Dark')),
                          DropdownMenuItem(value: 'light', child: Text('Material Light')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(SettingsThemeChanged(val));
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language_outlined, color: AppTheme.primary),
                      title: const Text('App Language', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Interface locale framework', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: DropdownButton<String>(
                        value: state.languageCode,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English (US)')),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                          DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                          DropdownMenuItem(value: 'fr', child: Text('Français')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(SettingsLanguageChanged(val));
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Section 2: Security & Lock
                  _sectionHeader('Security & Auto-Lock'),
                  _buildCard([
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primary),
                      title: const Text('Biometric Authentication', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Require Windows Hello / Touch ID / PIN on launch', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      value: state.biometricsEnabled,
                      onChanged: (val) {
                        context.read<SettingsBloc>().add(SettingsBiometricsToggled(val));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: AppTheme.primary),
                      title: const Text('Auto-Lock Timeout', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(state.autoLockMinutes == 0 ? 'Never auto-lock' : 'Lock after ${state.autoLockMinutes} min inactivity', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: DropdownButton<int>(
                        value: state.autoLockMinutes,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Minute')),
                          DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                          DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                          DropdownMenuItem(value: 0, child: Text('Disabled')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(SettingsAutoLockChanged(val));
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.content_paste_off_outlined, color: AppTheme.primary),
                      title: const Text('Clipboard Auto-Wipe', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(state.clipboardClearSeconds == 0 ? 'Disabled' : 'Auto-clear after ${state.clipboardClearSeconds}s', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: DropdownButton<int>(
                        value: state.clipboardClearSeconds,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 Seconds')),
                          DropdownMenuItem(value: 30, child: Text('30 Seconds')),
                          DropdownMenuItem(value: 60, child: Text('60 Seconds')),
                          DropdownMenuItem(value: 0, child: Text('Disabled')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(SettingsClipboardTimeoutChanged(val));
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Section 3: Encrypted Vault Backup
                  _sectionHeader('Encrypted Vault Backup & Migration'),
                  _buildCard([
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primary),
                      title: const Text('Export Encrypted Vault (.cybe)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Export passwords, secret notes & 2FA keys into an AES-256 backup file', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => BackupDialogs.showExportDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_download_outlined, color: AppTheme.primary),
                      title: const Text('Restore Encrypted Vault', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Import and decrypt a .cybe backup file with master password', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => BackupDialogs.showImportDialog(context),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Section 4: Anti-Coercion & Emergency Self-Destruct
                  _sectionHeader('Anti-Coercion & Emergency Panic Wipe'),
                  _buildCard([
                    ListTile(
                      leading: const Icon(Icons.no_encryption_gmailerrorred_rounded, color: AppTheme.warning),
                      title: const Text('Emergency Duress PIN', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Configure secondary PIN that triggers silent vault self-destruction if forced to unlock', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => _showDuressSetupDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
                      title: const Text('Instant Emergency Self-Destruct', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Immediately wipe all vaults, keys, and encrypted files from disk', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                      onTap: () => _showInstantPanicWipeConfirm(context),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDuressSetupDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Configure Duress PIN', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If forced to unlock Cybe Security under physical coercion or device seizure, entering this Duress PIN on the lock screen will seamlessly open a fake clean app while silently wiping all encrypted vaults and keys in the background.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Enter Emergency Duress PIN...',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Duress PIN must be at least 4 digits.')),
                );
                return;
              }
              context.read<AuthBloc>().add(AuthConfigureDuressPin(pin));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Duress Panic PIN successfully configured.'),
                  backgroundColor: AppTheme.safe,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.black),
            child: const Text('Save Duress PIN'),
          ),
        ],
      ),
    );
  }

  void _showInstantPanicWipeConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('SELF-DESTRUCT PANIC WIPE?', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: const Text(
          'WARNING: This will permanently overwrite and delete all encrypted files, passwords, secret notes, 2FA tokens, and master cryptographic keys on disk.\n\nTHIS ACTION CANNOT BE UNDONE!',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DuressWipeService.executePanicWipeSequence();
              if (context.mounted) {
                context.read<AuthBloc>().add(AuthLockApp());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Panic wipe sequence executed. All vault keys & data purged.'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('EXECUTE PANIC WIPE'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(children: children),
    );
  }
}
