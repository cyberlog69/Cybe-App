import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/usb_bloc.dart';
import '../models/usb_history_entry.dart';

/// Root screen — creates its own scoped [UsbBloc].
class UsbMonitorScreen extends StatelessWidget {
  const UsbMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsbBloc()..add(UsbInitialize()),
      child: const _UsbMonitorView(),
    );
  }
}

class _UsbMonitorView extends StatelessWidget {
  const _UsbMonitorView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UsbBloc, UsbState>(
      builder: (context, state) {
        if (state is UsbInitial || state is UsbLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('USB Security Monitor'),
              backgroundColor: AppTheme.background,
            ),
            body: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        if (state is! UsbLoaded) return const SizedBox.shrink();

        return Scaffold(
          appBar: AppBar(
            title: const Text('USB Security Monitor'),
            backgroundColor: AppTheme.background,
            actions: [
              if (state.history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear History',
                  onPressed: () =>
                      context.read<UsbBloc>().add(UsbHistoryCleared()),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: state.isSupported
                    ? () => context.read<UsbBloc>().add(UsbScanRequested())
                    : null,
              ),
            ],
          ),
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: ResponsiveCenter(
              maxWidth: 1000,
              child: state.isSupported
                  ? _buildActiveView(context, state)
                  : _buildRestrictedView(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveView(BuildContext context, UsbLoaded state) {
    final osLabel = Platform.isWindows ? 'Windows' : 'Android';
    final devices = state.devicesWithTrust;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status header ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.usb, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$osLabel USB Monitor Active',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      '${devices.length} device${devices.length != 1 ? 's' : ''} '
                      '\u2022 ${state.history.length} events logged',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.safe,
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.safe.withOpacity(0.6), blurRadius: 8)
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Connected devices ─────────────────────────────────────────────
        const Text('Connected USB Devices',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 10),
        if (devices.isEmpty)
          _emptyCard(Icons.usb_off_rounded, 'No USB devices detected')
        else
          ...devices.map((d) => _DeviceCard(
                device: d,
                onTrust: () =>
                    context.read<UsbBloc>().add(UsbDeviceTrusted(d)),
                onBlock: () =>
                    context.read<UsbBloc>().add(UsbDeviceBlocked(d)),
              )),

        const SizedBox(height: 24),

        // ── Connection history ────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Connection History',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            if (state.history.isNotEmpty)
              Text('${state.history.length} events',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        if (state.history.isEmpty)
          _emptyCard(Icons.history, 'No USB events recorded yet.')
        else
          ...state.history.take(30).map((e) => _HistoryRow(entry: e)),
      ],
    );
  }

  Widget _emptyCard(IconData icon, String label) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E1E30)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );

  Widget _buildRestrictedView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.warning.withOpacity(0.15),
                ),
                child:
                    const Icon(Icons.usb, color: AppTheme.warning, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('USB Security Guidance',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Real-time hardware USB monitoring is active on Windows and Android.\n\n'
                'On restricted platforms (such as iOS), use charge-only cables '
                'and disable data transfer mode when connecting to public ports.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('USB Security Best Practices',
                        style: TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      '\u2022 Never connect untrusted USB drives or unknown cables\n'
                      '\u2022 Use data-blocker USB adaptors for public charging stations\n'
                      '\u2022 Disable USB auto-run / auto-play in OS settings\n'
                      '\u2022 Keep OS drivers updated to prevent USB stack vulnerabilities',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Device card ──────────────────────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final UsbDeviceInfo device;
  final VoidCallback onTrust;
  final VoidCallback onBlock;
  const _DeviceCard(
      {required this.device, required this.onTrust, required this.onBlock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: device.isTrusted
                ? AppTheme.safe.withOpacity(0.3)
                : AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (device.isTrusted ? AppTheme.safe : AppTheme.warning)
                      .withOpacity(0.15),
                ),
                child: Icon(Icons.usb_rounded,
                    color:
                        device.isTrusted ? AppTheme.safe : AppTheme.warning,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('VID: ${device.vendorId}  \u2022  PID: ${device.productId}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (device.isTrusted ? AppTheme.safe : AppTheme.warning)
                          .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  device.isTrusted ? 'Trusted' : 'Unknown',
                  style: TextStyle(
                      color: device.isTrusted
                          ? AppTheme.safe
                          : AppTheme.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!device.isTrusted) ...
          [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTrust,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.safe,
                      side: const BorderSide(color: AppTheme.safe),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Trust',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBlock,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.block_outlined, size: 16),
                    label: const Text('Block',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── History row ──────────────────────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final UsbHistoryEntry entry;
  const _HistoryRow({required this.entry});

  IconData get _icon {
    switch (entry.eventType) {
      case 'connected':
        return Icons.usb_rounded;
      case 'disconnected':
        return Icons.usb_off_rounded;
      case 'trusted':
        return Icons.verified_outlined;
      case 'blocked':
        return Icons.block_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (entry.eventType) {
      case 'connected':
        return AppTheme.primary;
      case 'disconnected':
        return AppTheme.textSecondary;
      case 'trusted':
        return AppTheme.safe;
      case 'blocked':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  String get _label {
    switch (entry.eventType) {
      case 'connected':
        return '${entry.deviceName} connected';
      case 'disconnected':
        return '${entry.deviceName} disconnected';
      case 'trusted':
        return '${entry.deviceName} marked as trusted';
      case 'blocked':
        return '${entry.deviceName} blocked by user';
      default:
        return entry.deviceName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12))),
          Text(DateFormat('HH:mm:ss').format(entry.timestamp),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
