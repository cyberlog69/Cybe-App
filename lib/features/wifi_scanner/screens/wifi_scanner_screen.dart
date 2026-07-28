import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

enum WifiSecurity { open, wep, wpa, wpa2, wpa3 }

extension WifiSecurityExt on WifiSecurity {
  Color get color {
    switch (this) {
      case WifiSecurity.open: return AppTheme.danger;
      case WifiSecurity.wep: return AppTheme.danger;
      case WifiSecurity.wpa: return AppTheme.warning;
      case WifiSecurity.wpa2: return AppTheme.safe;
      case WifiSecurity.wpa3: return AppTheme.primary;
    }
  }
  String get label {
    switch (this) {
      case WifiSecurity.open: return 'OPEN';
      case WifiSecurity.wep: return 'WEP';
      case WifiSecurity.wpa: return 'WPA';
      case WifiSecurity.wpa2: return 'WPA2';
      case WifiSecurity.wpa3: return 'WPA3';
    }
  }
  String get riskLabel {
    switch (this) {
      case WifiSecurity.open: return 'High Risk — No encryption';
      case WifiSecurity.wep: return 'High Risk — Deprecated protocol';
      case WifiSecurity.wpa: return 'Medium Risk — Use WPA2/3';
      case WifiSecurity.wpa2: return 'Secure';
      case WifiSecurity.wpa3: return 'Most Secure';
    }
  }
}

class _WifiNetwork {
  final String ssid;
  final String bssid;
  final String capabilities;
  final int level;

  _WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.capabilities,
    required this.level,
  });

  factory _WifiNetwork.fromAp(WiFiAccessPoint ap) => _WifiNetwork(
    ssid: ap.ssid,
    bssid: ap.bssid,
    capabilities: ap.capabilities,
    level: ap.level,
  );
}

WifiSecurity classifyCapabilities(String? caps) {
  if (caps == null || caps.isEmpty || (!caps.contains('WPA') && !caps.contains('WEP'))) {
    return WifiSecurity.open;
  }
  if (caps.contains('WPA3')) return WifiSecurity.wpa3;
  if (caps.contains('WPA2')) return WifiSecurity.wpa2;
  if (caps.contains('WPA')) return WifiSecurity.wpa;
  if (caps.contains('WEP')) return WifiSecurity.wep;
  return WifiSecurity.open;
}

class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});
  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen>
    with SingleTickerProviderStateMixin {
  List<_WifiNetwork> _networks = [];
  bool _scanning = false;
  String? _error;
  late AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _error = null; });

    if (Platform.isWindows) {
      final windowsNetworks = await _scanWindowsWifi();
      if (mounted) {
        setState(() {
          _networks = windowsNetworks;
          _scanning = false;
          if (windowsNetworks.isEmpty) {
            _error = 'No Wi-Fi networks found or Wi-Fi adapter is turned off.';
          }
        });
      }
      return;
    }

    if (Platform.isLinux || Platform.isMacOS) {
      setState(() {
        _scanning = false;
        _error = 'Wi-Fi radio scanning is active on Windows and Mobile. Check your Network Dashboard for active adapter details.';
      });
      return;
    }

    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      setState(() { _error = 'Location permission is required to scan Wi-Fi networks.'; _scanning = false; });
      return;
    }
    try {
      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (can != CanStartScan.yes) {
        setState(() { _error = 'Cannot start Wi-Fi scan on this device.'; _scanning = false; });
        return;
      }
      await WiFiScan.instance.startScan();
      final result = await WiFiScan.instance.getScannedResults();
      if (mounted) {
        setState(() {
          _networks = result.map((ap) => _WifiNetwork.fromAp(ap)).toList();
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Scan failed: $e'; _scanning = false; });
      }
    }
  }

  Future<List<_WifiNetwork>> _scanWindowsWifi() async {
    try {
      final result = await Process.run('netsh', ['wlan', 'show', 'networks', 'mode=bssid']);
      if (result.exitCode != 0) return [];

      final lines = const LineSplitter().convert(result.stdout.toString());
      final points = <_WifiNetwork>[];

      String currentSsid = '';
      String currentAuth = '';
      String currentBssid = '';

      final ssidReg = RegExp(r'^SSID\s+\d+\s+:\s*(.*)$');
      final authReg = RegExp(r'Authentication\s+:\s*(.*)$');
      final bssidReg = RegExp(r'BSSID\s+\d+\s+:\s*(.*)$');
      final signalReg = RegExp(r'Signal\s+:\s*(\d+)%');

      for (final rawLine in lines) {
        final line = rawLine.trim();

        final ssidMatch = ssidReg.firstMatch(line);
        if (ssidMatch != null) {
          currentSsid = ssidMatch.group(1)?.trim() ?? '';
          continue;
        }

        final authMatch = authReg.firstMatch(line);
        if (authMatch != null) {
          currentAuth = authMatch.group(1)?.trim() ?? '';
          continue;
        }

        final bssidMatch = bssidReg.firstMatch(line);
        if (bssidMatch != null) {
          currentBssid = bssidMatch.group(1)?.trim() ?? '';
          continue;
        }

        final signalMatch = signalReg.firstMatch(line);
        if (signalMatch != null) {
          final pct = int.tryParse(signalMatch.group(1) ?? '50') ?? 50;
          final dbm = (pct / 2 - 100).round();

          points.add(_WifiNetwork(
            ssid: currentSsid,
            bssid: currentBssid.isEmpty ? '00:00:00:00:00:00' : currentBssid,
            capabilities: currentAuth.toUpperCase(),
            level: dbm,
          ));
        }
      }

      return points;
    } catch (e) {
      debugPrint('Windows Wi-Fi scan error: $e');
      return [];
    }
  }

  // Detect possible evil twin: multiple APs with same SSID, different BSSID
  bool _isEvilTwin(_WifiNetwork net) {
    if (net.ssid.isEmpty) return false;
    final sameSSID = _networks.where((a) => a.ssid == net.ssid).toList();
    return sameSSID.length > 1;
  }

  int get _openCount => _networks.where((ap) => classifyCapabilities(ap.capabilities) == WifiSecurity.open).length;
  int get _dangerCount => _networks.where((ap) {
    final s = classifyCapabilities(ap.capabilities);
    return s == WifiSecurity.open || s == WifiSecurity.wep;
  }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Security Scanner'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _startScan,
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: Column(
            children: [
              // Summary bar
              if (_networks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E1E30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${_networks.length}', 'Found', AppTheme.primary),
                      _stat('$_openCount', 'Open', AppTheme.danger),
                      _stat('$_dangerCount', 'At Risk', AppTheme.warning),
                      _stat('${_networks.length - _dangerCount}', 'Secure', AppTheme.safe),
                    ],
                  ),
                ),
              // Error message
              if (_error != null && !_scanning)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.warning),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4))),
                    ],
                  ),
                ),
              // Scanning indicator
              if (_scanning)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RotationTransition(
                          turns: _scanAnim,
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary, width: 3),
                            ),
                            child: const Icon(Icons.wifi_find, color: AppTheme.primary, size: 36),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Scanning for Wi-Fi networks...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              // AP List
              if (!_scanning)
                Expanded(
                  child: _networks.isEmpty
                      ? const Center(child: Text('No networks found. Try rescanning.', style: TextStyle(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _networks.length,
                          itemBuilder: (_, i) {
                            final net = _networks[i];
                            final security = classifyCapabilities(net.capabilities);
                            final isEvil = _isEvilTwin(net);
                            return _WifiCard(network: net, security: security, isEvilTwin: isEvil);
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _WifiCard extends StatelessWidget {
  final _WifiNetwork network;
  final WifiSecurity security;
  final bool isEvilTwin;
  const _WifiCard({required this.network, required this.security, required this.isEvilTwin});

  int get _signalBars {
    final level = network.level;
    if (level >= -50) return 4;
    if (level >= -65) return 3;
    if (level >= -75) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEvilTwin ? AppTheme.danger.withOpacity(0.5)
            : security.color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: security.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  network.ssid.isEmpty ? '(Hidden Network)' : network.ssid,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: security.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(security.label, style: TextStyle(color: security.color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('BSSID: ${network.bssid}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.signal_wifi_4_bar, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${network.level} dBm  •  $_signalBars/4 bars', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              const Spacer(),
              Text(security.riskLabel, style: TextStyle(color: security.color, fontSize: 11)),
            ],
          ),
          if (isEvilTwin) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.danger, size: 14),
                  SizedBox(width: 4),
                  Text('⚠ Possible Evil Twin Attack Detected', style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
