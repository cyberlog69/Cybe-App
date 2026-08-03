import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../models/mitm_threat_report.dart';
import '../services/mitm_detector_service.dart';
import '../services/secure_dns_vpn_service.dart';

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
  bool _isDnsShieldActive = SecureDnsVpnService.isDnsShieldActive;
  bool _isVpnTunnelActive = SecureDnsVpnService.isVpnTunnelActive;
  DnsProvider _selectedDnsProvider = SecureDnsVpnService.selectedProvider;
  List<VpnProfile> _vpnProfiles = [];
  Timer? _autoShieldTimer;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadVpnProfiles();
    _runScan();
  }

  @override
  void dispose() {
    _autoShieldTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadVpnProfiles() async {
    final profiles = await SecureDnsVpnService.loadSavedVpnProfiles();
    if (mounted) setState(() => _vpnProfiles = profiles);
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
          content: Text('Real-Time Network Threat Shield auto-monitoring enabled.'),
          backgroundColor: AppTheme.safe,
        ),
      );
    }
  }

  Future<void> _toggleDnsShield(bool value) async {
    await SecureDnsVpnService.toggleDnsShield(value, provider: _selectedDnsProvider);
    if (mounted) {
      setState(() => _isDnsShieldActive = value);
      _runScan();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Encrypted DNS Shield active via ${_selectedDnsProvider.displayName}.'
                : 'Encrypted DNS Shield disabled.',
          ),
          backgroundColor: value ? AppTheme.safe : AppTheme.warning,
        ),
      );
    }
  }

  Future<void> _toggleVpnTunnel(bool value) async {
    if (value && _vpnProfiles.isEmpty) {
      _showImportVpnDialog();
      return;
    }

    await SecureDnsVpnService.toggleVpnTunnel(value);
    if (mounted) {
      setState(() => _isVpnTunnelActive = value);
      _runScan();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'OpenVPN Secure Tunnel connected. All network traffic encrypted.'
                : 'OpenVPN Tunnel disconnected.',
          ),
          backgroundColor: value ? AppTheme.safe : AppTheme.warning,
        ),
      );
    }
  }

  Future<void> _importOvpnProfile() async {
    try {
      final profile = await SecureDnsVpnService.importOvpnProfile();
      if (profile != null) {
        await _loadVpnProfiles();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported OpenVPN profile "${profile.name}".'),
            backgroundColor: AppTheme.safe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showImportVpnDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_lock_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('OpenVPN Tunnel Manager',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No OpenVPN (.ovpn) configuration profile found.\n\nImport a custom .ovpn file from your VPN provider to establish an encrypted tunnel over Wi-Fi and Cellular Mobile Data.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _importOvpnProfile();
            },
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Import .ovpn File'),
          ),
        ],
      ),
    );
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
        title: const Text('Wi-Fi & Cellular Threat Shield'),
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
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Native Protection Active on ${Platform.operatingSystem.toUpperCase()}: Low-level ARP inspection, SSL Stripping, DNS Hijacking, DoH Encrypted DNS Shield, and OpenVPN Manager are 100% active.',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
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

              // Encrypted DNS & OpenVPN Shield Card
              _buildDnsVpnShieldCard(),
              const SizedBox(height: 16),

              // Diagnostic Probe Checks Header
              const Text(
                'Wi-Fi & Mobile Network Diagnostic Probes',
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
                      : 'DNS response verified against trusted endpoints (${_selectedDnsProvider.displayName}).',
                  isPassed: !report.isDnsHijacked,
                  icon: Icons.dns_outlined,
                ),
                const SizedBox(height: 10),
                _buildProbeCard(
                  title: 'Active Network Gateway Inspection',
                  subtitle: 'Gateway IP: ${report.gatewayIp} | Network: ${report.ssid}',
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
                        label: const Text('View Network Table'),
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
            'Network: ${report?.ssid ?? 'Unknown'} • Gateway: ${report?.gatewayIp ?? 'Checking...'}',
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
                const Text('Gateway MAC / Stack: ',
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
                Text('Continuous background ARP, SSL & Mobile probe every 10s',
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

  Widget _buildDnsVpnShieldCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isDnsShieldActive || _isVpnTunnelActive)
              ? AppTheme.safe.withValues(alpha: 0.4)
              : const Color(0xFF1E1E30),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.vpn_lock_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Encrypted DNS & OpenVPN Shield',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('Prevents Wi-Fi & Cellular DNS poisoning & eavesdropping',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Provider Choice Chips
          const Text('Select Secure DNS Resolver:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _dnsChoiceChip(DnsProvider.cloudflare),
              _dnsChoiceChip(DnsProvider.google),
              _dnsChoiceChip(DnsProvider.openDns),
            ],
          ),
          const SizedBox(height: 14),

          // Encrypted DNS Shield Switch
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DoH Encrypted DNS Shield',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Routes all domain requests over encrypted HTTPS sockets',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _isDnsShieldActive,
                onChanged: _toggleDnsShield,
              ),
            ],
          ),
          const Divider(height: 24),

          // OpenVPN Tunnel Toggle & Importer
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vpnProfiles.isNotEmpty
                          ? 'OpenVPN Profile: ${_vpnProfiles.first.name}'
                          : 'OpenVPN Secure Tunnel',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      _vpnProfiles.isNotEmpty
                          ? '${_vpnProfiles.first.remoteHost}:${_vpnProfiles.first.remotePort} (${_vpnProfiles.first.proto})'
                          : 'Import custom .ovpn file for full tunnel encryption',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isVpnTunnelActive,
                onChanged: _toggleVpnTunnel,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Import .ovpn Button
          OutlinedButton.icon(
            onPressed: _importOvpnProfile,
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: Text(_vpnProfiles.isEmpty ? 'Import .ovpn Profile' : 'Import New .ovpn Profile'),
          ),
        ],
      ),
    );
  }

  Widget _dnsChoiceChip(DnsProvider provider) {
    final isSelected = _selectedDnsProvider == provider;
    return ChoiceChip(
      label: Text(provider.displayName),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDnsProvider = provider);
          SecureDnsVpnService.setDnsProvider(provider);
          if (_isDnsShieldActive) {
            _toggleDnsShield(true);
          }
        }
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.25),
      backgroundColor: AppTheme.surfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.transparent,
        ),
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
        border: Border.all(color: const Color(0xFF1E1E30)),
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
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Icon(
            isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded,
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
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Text(alert.title,
                  style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(alert.description,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Recommendation: ${alert.recommendation}',
              style: const TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ],
      ),
    );
  }

  void _showArpTableDialog(MitmThreatReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_rows_outlined, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Network Device Table',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gateway IP: ${report.gatewayIp} | MAC: ${report.gatewayMac}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const Divider(height: 20),
              if (report.arpCacheTable.isEmpty)
                const Text('No network device table entries available.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: report.arpCacheTable.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(entry.key,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontFamily: 'monospace',
                                    fontSize: 12)),
                            const Spacer(),
                            Text(entry.value,
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
