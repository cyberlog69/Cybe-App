import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/totp_bloc.dart';
import '../models/totp_item.dart';
import '../widgets/qr_scanner_sheet.dart';

class TotpScreen extends StatelessWidget {
  const TotpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TotpBloc()..add(TotpLoad()),
      child: const _TotpView(),
    );
  }
}

class _TotpView extends StatelessWidget {
  const _TotpView();

  void _showAddDialog(BuildContext context) {
    final issuerCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final secretCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Add 2FA Secret Key', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: issuerCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Service Name (e.g. Google, GitHub)', hintText: 'GitHub'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Account / Email', hintText: 'user@example.com'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secretCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Secret Key (Base32)', hintText: 'JBSWY3DPEHPK3PXP'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (secretCtrl.text.trim().isEmpty) return;
              final item = TotpItem.create(
                issuer: issuerCtrl.text.trim().isEmpty ? 'Account' : issuerCtrl.text,
                accountName: accountCtrl.text,
                secret: secretCtrl.text,
              );
              context.read<TotpBloc>().add(TotpAdd(item));
              Navigator.pop(dialogCtx);
            },
            child: const Text('Add Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQr(BuildContext context) async {
    final item = await showModalBottomSheet<TotpItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QrScannerSheet(),
    );

    if (item != null && context.mounted) {
      context.read<TotpBloc>().add(TotpAdd(item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added 2FA for ${item.issuer}'), backgroundColor: AppTheme.safe),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2FA Authenticator'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan QR Code',
            onPressed: () => _scanQr(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Manual Add',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: BlocBuilder<TotpBloc, TotpState>(
            builder: (context, state) {
              if (state is TotpLoading || state is TotpInitial) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (state is TotpLoaded) {
                if (state.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No 2FA Accounts Configured', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Scan a 2FA QR code or enter secret key manually', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _scanQr(context),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan QR Code'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showAddDialog(context),
                              icon: const Icon(Icons.edit_note_rounded),
                              label: const Text('Manual Key'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  itemBuilder: (ctx, i) {
                    final item = state.items[i];
                    return _TotpCard(item: item);
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

class _TotpCard extends StatelessWidget {
  final TotpItem item;
  const _TotpCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final code = item.currentCode;
    final formattedCode = code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
    final progress = item.timeRemainingFraction;
    final secs = item.secondsRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44, height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation(secs <= 5 ? AppTheme.danger : AppTheme.primary),
                ),
                Text('$secs', style: TextStyle(color: secs <= 5 ? AppTheme.danger : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.issuer, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                if (item.accountName.isNotEmpty)
                  Text(item.accountName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(formattedCode, style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Copy Code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied code for ${item.issuer}'), duration: const Duration(seconds: 2)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Delete Account',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Delete 2FA Account?', style: TextStyle(color: AppTheme.textPrimary)),
                  content: Text('Remove ${item.issuer} (${item.accountName})?', style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                context.read<TotpBloc>().add(TotpDelete(item.id));
              }
            },
          ),
        ],
      ),
    );
  }
}
