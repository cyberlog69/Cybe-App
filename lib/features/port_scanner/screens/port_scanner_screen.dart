import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../services/port_scanner_service.dart';

class PortScannerScreen extends StatefulWidget {
  const PortScannerScreen({super.key});

  @override
  State<PortScannerScreen> createState() => _PortScannerScreenState();
}

class _PortScannerScreenState extends State<PortScannerScreen> {
  final _hostCtrl = TextEditingController(text: '127.0.0.1');
  bool _scanning = false;
  List<PortScanResult>? _results;

  Future<void> _runPortScan() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _scanning = true;
      _results = null;
    });

    final res = await PortScannerService.scanHost(host);

    if (mounted) {
      setState(() {
        _scanning = false;
        _results = res;
      });
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Port Scanner'),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Input Card
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
                    const Text('Scan Target IP Address for Open Ports', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Checks common TCP ports (SSH, Telnet, SMB, UPnP, RDP, HTTP) for vulnerabilities.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 192.168.1.1 or 127.0.0.1',
                              prefixIcon: Icon(Icons.lan_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _scanning ? null : _runPortScan,
                          icon: _scanning
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.radar),
                          label: Text(_scanning ? 'Scanning...' : 'Scan Ports'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Results
              if (_results != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Open Ports Found (${_results!.length})', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (_results!.isNotEmpty)
                      Text('${_results!.where((r) => r.risk == PortRiskLevel.danger).length} High Risk', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                if (_results!.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E1E30))),
                    child: const Column(
                      children: [
                        Icon(Icons.shield_outlined, color: AppTheme.safe, size: 48),
                        SizedBox(height: 12),
                        Text('No Common Open Ports Detected', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Host appears hardened with stealth firewall rules.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ..._results!.map((r) {
                    final color = r.risk == PortRiskLevel.danger ? AppTheme.danger : r.risk == PortRiskLevel.warning ? AppTheme.warning : AppTheme.safe;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(':${r.port}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(r.serviceName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text('${r.latencyMs} ms', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(r.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
