import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';

class _UsbDevice {
  final String vendorId;
  final String productId;
  final String? manufacturer;
  final String? productName;
  final DateTime connectedAt;
  bool isTrusted;

  _UsbDevice({
    required this.vendorId,
    required this.productId,
    this.manufacturer,
    this.productName,
    required this.connectedAt,
    this.isTrusted = false,
  });

  String get displayName => productName ?? manufacturer ?? 'Unknown USB Device';
}

class _UsbHistoryEntry {
  final String description;
  final DateTime time;
  final bool connected;
  _UsbHistoryEntry({required this.description, required this.time, required this.connected});
}

class UsbMonitorScreen extends StatefulWidget {
  const UsbMonitorScreen({super.key});
  @override
  State<UsbMonitorScreen> createState() => _UsbMonitorScreenState();
}

class _UsbMonitorScreenState extends State<UsbMonitorScreen> {
  List<_UsbDevice> _connectedDevices = [];
  final List<_UsbHistoryEntry> _history = [];
  bool _isSupported = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _isSupported = Platform.isAndroid || Platform.isWindows;
    if (_isSupported) {
      _startMonitoring();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _scanDevices();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _scanDevices());
  }

  Future<void> _scanDevices() async {
    try {
      List<_UsbDevice> newDevices = [];

      if (Platform.isAndroid) {
        final ports = await UsbSerial.listDevices();
        newDevices = ports.map((p) => _UsbDevice(
          vendorId: p.vid?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'Unknown',
          productId: p.pid?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'Unknown',
          manufacturer: p.manufacturerName,
          productName: p.productName,
          connectedAt: DateTime.now(),
        )).toList();
      } else if (Platform.isWindows) {
        newDevices = await _scanWindowsDevices();
      }

      // Detect new connections
      for (final device in newDevices) {
        final alreadyKnown = _connectedDevices.any(
          (d) => d.displayName == device.displayName || (d.vendorId != 'N/A' && d.vendorId == device.vendorId && d.productId == device.productId));
        if (!alreadyKnown) {
          _history.insert(0, _UsbHistoryEntry(
            description: '${device.displayName} ${device.vendorId != "N/A" ? "(VID:${device.vendorId})" : ""}',
            time: DateTime.now(),
            connected: true,
          ));
        }
      }

      // Detect disconnections
      for (final old in _connectedDevices) {
        final stillPresent = newDevices.any(
          (d) => d.displayName == old.displayName || (d.vendorId != 'N/A' && d.vendorId == old.vendorId && d.productId == old.productId));
        if (!stillPresent) {
          _history.insert(0, _UsbHistoryEntry(
            description: '${old.displayName} disconnected',
            time: DateTime.now(),
            connected: false,
          ));
        }
      }

      if (mounted) {
        setState(() => _connectedDevices = newDevices);
      }
    } catch (e) {
      debugPrint('USB scan error: $e');
    }
  }

  Future<List<_UsbDevice>> _scanWindowsDevices() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-PnpDevice -PresentOnly -Class USB,Ports | Select-Object FriendlyName, InstanceId, Status | ConvertTo-Json'
      ]);
      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        return [];
      }

      final String rawJson = result.stdout.toString().trim();
      dynamic decoded;
      try {
        decoded = jsonDecode(rawJson);
      } catch (_) {
        return [];
      }

      final List<dynamic> items = decoded is List ? decoded : [decoded];
      final devices = <_UsbDevice>[];

      final vidReg = RegExp(r'VID_([0-9A-Fa-f]{4})', caseSensitive: false);
      final pidReg = RegExp(r'PID_([0-9A-Fa-f]{4})', caseSensitive: false);

      for (final item in items) {
        if (item is! Map) continue;
        final name = (item['FriendlyName'] ?? 'USB Device').toString();
        final instanceId = (item['InstanceId'] ?? '').toString();

        final vidMatch = vidReg.firstMatch(instanceId);
        final pidMatch = pidReg.firstMatch(instanceId);

        final vid = vidMatch != null ? vidMatch.group(1)!.toUpperCase() : 'N/A';
        final pid = pidMatch != null ? pidMatch.group(1)!.toUpperCase() : 'N/A';

        devices.add(_UsbDevice(
          vendorId: vid,
          productId: pid,
          productName: name,
          connectedAt: DateTime.now(),
        ));
      }

      return devices;
    } catch (e) {
      debugPrint('Windows USB Query error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Security Monitor'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSupported ? _scanDevices : null,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: _isSupported ? _buildActiveMonitorView() : _buildRestrictedView(),
        ),
      ),
    );
  }

  Widget _buildActiveMonitorView() {
    final osLabel = Platform.isWindows ? 'Windows' : 'Android';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
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
                    Text('$osLabel USB Monitor Active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${_connectedDevices.length} USB controller / device${_connectedDevices.length != 1 ? 's' : ''} detected',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.safe,
                  boxShadow: [BoxShadow(color: AppTheme.safe.withOpacity(0.6), blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Connected devices
        const Text('Connected USB Devices', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (_connectedDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E1E30)),
            ),
            child: const Column(
              children: [
                Icon(Icons.usb_off_rounded, size: 40, color: AppTheme.textSecondary),
                SizedBox(height: 8),
                Text('No USB devices detected', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          ...(_connectedDevices.map((d) => _DeviceCard(
            device: d,
            onTrust: () => setState(() => d.isTrusted = true),
            onBlock: () => setState(() {
              _connectedDevices.remove(d);
              _history.insert(0, _UsbHistoryEntry(
                description: '${d.displayName} blocked by user',
                time: DateTime.now(),
                connected: false,
              ));
            }),
          ))),

        const SizedBox(height: 24),

        // Connection history
        const Text('Connection History', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E1E30)),
            ),
            child: const Text('No USB events recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
          )
        else
          ...(_history.take(20).map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E1E30)),
            ),
            child: Row(
              children: [
                Icon(
                  e.connected ? Icons.usb_rounded : Icons.usb_off_rounded,
                  color: e.connected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                Text(DateFormat('HH:mm:ss').format(e.time), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ))),
      ],
    );
  }

  Widget _buildRestrictedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withOpacity(0.15),
              ),
              child: const Icon(Icons.usb, color: AppTheme.warning, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('USB Security Guidance', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Real-time hardware USB monitoring is active on Windows and Android.\n\nOn restricted platforms (such as iOS), use charge-only cables and disable data transfer mode when connecting to public ports.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USB Security Best Practices', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Never connect untrusted USB drives or unknown cables\n• Use data-blocker USB adaptors for public charging stations\n• Disable USB auto-run / auto-play in operating system settings\n• Keep host OS drivers updated to prevent USB stack vulnerabilities',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final _UsbDevice device;
  final VoidCallback onTrust;
  final VoidCallback onBlock;
  const _DeviceCard({required this.device, required this.onTrust, required this.onBlock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: device.isTrusted ? AppTheme.safe.withOpacity(0.3) : AppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (device.isTrusted ? AppTheme.safe : AppTheme.warning).withOpacity(0.15),
                ),
                child: Icon(Icons.usb_rounded, color: device.isTrusted ? AppTheme.safe : AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('VID: ${device.vendorId}  •  PID: ${device.productId}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (device.isTrusted ? AppTheme.safe : AppTheme.warning).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  device.isTrusted ? 'Trusted' : 'Unknown',
                  style: TextStyle(color: device.isTrusted ? AppTheme.safe : AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!device.isTrusted) ...[
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
                    label: const Text('Trust', style: TextStyle(fontSize: 13)),
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
                    label: const Text('Block', style: TextStyle(fontSize: 13)),
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
