import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/ssh_keys_bloc.dart';
import '../models/ssh_key_entry.dart';

class SshKeysScreen extends StatelessWidget {
  const SshKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SshKeysBloc()..add(SshKeysLoad()),
      child: const _SshKeysView(),
    );
  }
}

class _SshKeysView extends StatelessWidget {
  const _SshKeysView();

  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final rawKeyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String keyType = 'SSH RSA';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add SSH / API Key', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Title / Label', hintText: 'AWS Prod / GitHub Deploy Key'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: keyType,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Key Type'),
                  items: const ['SSH RSA', 'SSH Ed25519', 'API Token', 'Private Certificate']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => keyType = v ?? 'SSH RSA'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rawKeyCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Private Key / API Secret', hintText: '-----BEGIN OPENSSH PRIVATE KEY-----...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || rawKeyCtrl.text.trim().isEmpty) return;
                final entry = SshKeyEntry.create(
                  title: titleCtrl.text,
                  keyType: keyType,
                  rawKey: rawKeyCtrl.text,
                  notes: notesCtrl.text,
                );
                context.read<SshKeysBloc>().add(SshKeysSave(entry));
                Navigator.pop(dialogCtx);
              },
              child: const Text('Save Key'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH & API Key Manager'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(context),
            tooltip: 'Add Key',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: BlocBuilder<SshKeysBloc, SshKeysState>(
            builder: (context, state) {
              if (state is SshKeysLoading || state is SshKeysInitial) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              if (state is SshKeysLoaded) {
                if (state.keys.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.key_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('No SSH or API Keys Stored', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Store SSH private keys & API secrets encrypted with AES-256', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Key'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.keys.length,
                  itemBuilder: (ctx, i) {
                    final key = state.keys[i];
                    return _KeyCard(keyEntry: key);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _KeyCard extends StatefulWidget {
  final SshKeyEntry keyEntry;
  const _KeyCard({required this.keyEntry});

  @override
  State<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<_KeyCard> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final key = widget.keyEntry;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(key.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(6)),
                child: Text(key.keyType, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(key.fingerprint, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 11)),
          const SizedBox(height: 10),
          if (_showRaw)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
              child: Text(key.rawKey, style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontSize: 11)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showRaw = !_showRaw),
                icon: Icon(_showRaw ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(_showRaw ? 'Hide Secret' : 'View Secret', style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                tooltip: 'Copy Secret Key',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: key.rawKey));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key copied to clipboard')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                onPressed: () => context.read<SshKeysBloc>().add(SshKeysDelete(key.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
