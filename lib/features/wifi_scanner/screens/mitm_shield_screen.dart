import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/mitm_threat_report.dart';
import '../services/mitm_detector_service.dart';

class MitmShieldScreen extends StatefulWidget {
  const MitmShieldScreen({super.key});

  @override
  State<MitmShieldScreen> createState() => _MitmShieldScreenState();
}

class _MitmShieldScreenState extends State<MitmShieldScreen>
    with SingleTickerProviderStateMixin {
  MitmThreatReport? _report;
  bool _isScanning = true;
  bool _autoShieldActive = false;
  Timer? _autoShieldTimer;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _runScan();
  }

  @override
  void dispose() {
    _autoShieldTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    setState(() => _isScanning = true);
    final report = await MitmDetectorService.runDiagnosticScan();
    if (mounted) {
      setState(() {
        _report = report;
        _isScanning = false;
      });
    }
  }

  void _toggleAutoShield(bool value) {
    setState(() => _autoShieldActive = value);
    _autoShieldTimer?.cancel();
    if (value) {
      _autoShieldTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _runScan();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Real-Time Wi-Fi Threat Shield auto-monitoring enabled.'),
          backgroundColor: AppTheme.safe,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    Color statusColor = AppTheme.safe;
    if (report != null) {
      if (report.threatStatus == 'CRITICAL MITM ATTACK') statusColor = AppTheme.danger;
      if (report.threatStatus == 'WARNING') statusColor = AppTheme.warning;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi MitM & ARP Threat Shield'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Run Diagnostic Scan',
            onPressed: _runScan,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 950,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!Platform.isAndroid && !Platform.isLinux)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'OS Security Mode: Low-level ARP table sockets are scoped to Android/Linux. SSL Stripping, DNS Hijacking & Gateway Probes are 100% Active.',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              // Radar & Shield Header
              _buildShieldRadarHeader(report, statusColor),
              const SizedBox(height: 16),

              // Auto-Shield Real-time Protection Toggle Card
              _buildAutoShieldToggleCard(),
              const SizedBox(height: 16),

              // Diagnostic Probe Checks Header
              const Text(
                'Wi-Fi Security Diagnostic Probes',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(height: 10),

              if (_isScanning && report == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else if (report != null) ...[
                _buildProbeCard(
                  title: 'ARP Cache & Gateway Integrity',
                  subtitle: report.isArpSpoofed
                      ? 'CRITICAL: Duplicate MACs detected in ARP table!'
                      : 'Gateway MAC (${report.gatewayMac}) verified consistent.',
                  isPassed: !report.isArpSpoofed,
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 10),
                _buildProbeCard(
                  title: 'HTTPS & TLS Certificate Inspection',
                  subtitle: report.isSslStripped
                      ? 'WARNING: SSL stripping or proxy interception flagged.'
                      : 'TLS probe passed. Encrypted HTTPS connections secure.',
                  isPassed: !report.isSslStripped,
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 10),
                _buildProbeCard(
                  title: 'DNS Resolution Sanity Check',
                  subtitle: report.isDnsHijacked
                      ? 'WARNING: Canonical DNS lookup failed or redirected.'
                      : 'DNS response verified against trusted endpoints.',
                  isPassed: !report.isDnsHijacked,
                  icon: Icons.dns_outlined,
                ),
                const SizedBox(height: 10),
                _buildProbeCard(
                  title: 'Active Network Gateway Inspection',
                  subtitle: 'Gateway IP: ${report.gatewayIp} | SSID: ${report.ssid}',
                  isPassed: report.isConnected,
                  icon: Icons.wifi_protected_setup_rounded,
                ),
                const SizedBox(height: 20),

                // Active Threat Alerts Section
                if (report.alerts.isNotEmpty) ...[
                  const Text(
                    'Active Security Threats Detected',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  ...report.alerts.map((alert) => _buildAlertCard(alert)),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showArpTableDialog(report),
                        icon: const Icon(Icons.table_rows_outlined, size: 18),
                        label: const Text('View ARP Cache Table'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _runScan,
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Rescan Network'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShieldRadarHeader(MitmThreatReport? report, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: _radarController,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.15),
                border: Border.all(color: statusColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                report?.threatStatus == 'CRITICAL MITM ATTACK'
                    ? Icons.warning_amber_rounded
                    : Icons.security_rounded,
                color: statusColor,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            report?.threatStatus ?? 'SCANNING NETWORK...',
            style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'SSID: ${report?.ssid ?? 'Unknown'} • Gateway: ${report?.gatewayIp ?? 'Checking...'}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gateway MAC: ',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text(
                  report?.gatewayMac ?? 'N/A',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoShieldToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Real-Time Background Auto-Shield',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text('Continuous background ARP & SSL probing every 10s',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _autoShieldActive,
            onChanged: _toggleAutoShield,
          ),
        ],
      ),
    );
  }

  Widget _buildProbeCard({
    required String title,
    required String subtitle,
    required bool isPassed,
    required IconData icon,
  }) {
    final color = isPassed ? AppTheme.safe : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: isPassed ? AppTheme.textSecondary : color, fontSize: 11)),
              ],
            ),
          ),
          Icon(
            isPassed ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(MitmThreatAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(alert.description,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.warning, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alert.recommendation,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showArpTableDialog(MitmThreatReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Local ARP Cache Table (/proc/net/arp)',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            if (report.arpCacheTable.isEmpty)
              const Center(
                child: Text('No active ARP entries found.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: report.arpCacheTable.length,
                  itemBuilder: (c, i) {
                    final ip = report.arpCacheTable.keys.elementAt(i);
                    final mac = report.arpCacheTable[ip]!;
                    final isGateway = ip == report.gatewayIp;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isGateway
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isGateway ? AppTheme.primary : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGateway ? Icons.router_rounded : Icons.devices_rounded,
                            size: 16,
                            color: isGateway ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(ip,
                              style: TextStyle(
                                  color: isGateway ? AppTheme.primary : AppTheme.textPrimary,
                                  fontWeight: isGateway ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12)),
                          if (isGateway) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('GATEWAY',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                          const Spacer(),
                          Text(mac,
                              style: const TextStyle(
                                  color: AppTheme.secondary,
                                  fontFamily: 'monospace',
                                  fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
